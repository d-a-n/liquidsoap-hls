# USAGE
# liquidsoap hls.liq -- <stream url> <# of segments> <path to fallback playlist> <timeout in munites>

### LOGGING
set("log.file", false)
set("log.stdout", true)

### INPUT PARAMS
stream_url = argv(1) #input streaming url
relive_segments = int_of_string(argv(2))
fallback_playlist = argv(3)
fallback_timeout = float_of_string(argv(4))

print("\n\nstarting with input params:\n\n    stream_url: #{stream_url}\n    relive_segments: #{relive_segments}\n    fallback_playlist: #{fallback_playlist}\n    fallback_timeout: #{fallback_timeout}\n\n\n\n")

### IMPLEMENTATION
timeout = ref fallback_timeout*60.0 #fallback timeout in seconds
output_formats = [
	("h", [("", "128000")]),
	("m", [("-ab:a 56k", "56000")]),
	("l", [("-ab:a 32k", "32000")])
]
stream_end_timestamp = ref 0.0

podcast_stream = (input.http(stream_url):source(*+1,0,0)) #workaround for mono/stereo bug as input -> always force mono and convert it to stereo
podcast_stream = audio_to_stereo(podcast_stream)
fallback_stream = mksafe(playlist(mode="random",reload=300,reload_mode="seconds",fallback_playlist))
main_source = fallback(track_sensitive=false, [podcast_stream, fallback_stream])


def check_stream()
	if source.is_ready(podcast_stream) then
		stream_end_timestamp := 0.0
	else
		if !stream_end_timestamp == 0.0 then
			stream_end_timestamp := gettimeofday()
		end
	end

	if !stream_end_timestamp > 0.0 then
		elapsed_time = gettimeofday() - !stream_end_timestamp
		print("--> check timeout #{elapsed_time}/#{!timeout} (#{!stream_end_timestamp})")
		if elapsed_time > !timeout then
			shutdown()
		end
	end
	1.0
end


def add_hls(path, ffmpeg_params) =
	resume_or_limit = ref ""
	if (relive_segments > 0) then
		resume_or_limit := string.concat(separator="", [!resume_or_limit, "--num-segment #{relive_segments}"])
	else
		resume_or_limit := string.concat(separator="", [!resume_or_limit, "-r"])
	end

	ffmpeg_cmd = 'ffmpeg -i - -y -c:a libfaac #{ffmpeg_params} -ac:a 1 -flags global_header -map 0:0 -f mpegts -vn -'
	segmenter_cmd = 'm3u8-segmenter -i - -d 10 -m stream.m3u8 #{!resume_or_limit} -p s -u ""'

	cmd = "mkdir -p #{path} && cd #{path} && #{ffmpeg_cmd} | #{segmenter_cmd}"
	print("running cmd: #{cmd}")

	output.external(
		%wav,
		fallible=true,
		cmd,
		main_source
	)
end

def process_output_formats(x) =
	path = fst(x)
	params = list.nth(snd(x),0)
	bitrate = fst(params)
	bandwith = snd(params)
	add_hls(path, bitrate)
	system('echo "#EXT-X-STREAM-INF:PROGRAM-ID=0,BANDWIDTH=#{bandwith}\n#{path}/stream.m3u8" >> stream.m3u8')
	print("added new stream -> path:#{path} bitrate:#{bitrate} bandwith:#{bandwith}")
end

system('rm stream.m3u8;echo "#EXTM3U" > stream.m3u8')
list.iter(process_output_formats,output_formats)
add_timeout(fast=false,1.0,check_stream)

output.dummy(blank())

