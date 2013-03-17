# liquidsoap-hls


Liquidsoap script for creating Http Live Streams (HLS) with a fallback when the stream becomes unavailable.

## Why do you need a fallback?

When your main stream stops (e.g. because of a network error) all your clients will be disconnected and have to restart the stream. With a fallback in place the player of your users keeps streaming the fallback content until you can broadcast again. So no interruption for your audience :)

## Usage

	liquidsoap hls.liq -- stream [no. of segments] [fallback playlist] [timeout]

### Params

|Params| Description |
| :------------- |:-------------| 
| **stream**      | stream url |
| **no. of segments**      | **(optional, defaults to 0)** - Number of segments to keep. one segment is 10 seconds, so if you want to have an relive of one minute you need to pass 6 (6 * 10 seconds = 1 minute). When no parameter is given or less than 1 the relive won't have a time limit.      |
| **fallback playlist** | **(optional, defaults to silence)** - local playlist of files or other streams      |
| **timeout** | **(optinal, default to 0)** - Timeout in minutes. After this time the relive will stop.     |

## Requirements
 * liquidsoap
 * ffmpeg
 * m3u8-segmenter (for resume support you have to use my fork)
