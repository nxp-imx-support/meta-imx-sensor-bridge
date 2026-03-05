#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2026 NXP


v4l2-ctl -d /dev/video0 --set-fmt-video=width=3840,height=2160,pixelformat=BG10

media-ctl -d /dev/media0 -r
media-ctl -d /dev/media0 -l '"os08a20 2-0036":0 -> "csidev-4ad30000.csi":0[1]'
media-ctl -d /dev/media0 -l '"csidev-4ad30000.csi":1 -> "4ac10000.syscon:formatter@20":0[1]'
media-ctl -d /dev/media0 -l '"4ac10000.syscon:formatter@20":1 -> "crossbar":2[1]'
media-ctl -d /dev/media0 -l '"crossbar":5 -> "mxc_isi.0":0[1]'
media-ctl -d /dev/media0 -l '"mxc_isi.0":1 -> "mxc_isi.0.capture":0[1]'

media-ctl -d /dev/media0 -R '"crossbar" [2/0 -> 5/0 [1], 2/2 -> 6/0 [0], 2/1 -> 7/0 [0], 2/3 -> 8/0 [0]]'
media-ctl -d /dev/media0 -R '"csidev-4ad30000.csi" [0/0 -> 1/0 [1], 0/1 -> 1/1 [0], 0/2 -> 1/2 [0], 0/3 -> 1/3 [0]]'
media-ctl -d /dev/media0 -R '"4ac10000.syscon:formatter@20" [0/0 -> 1/0 [1], 0/1 -> 1/1 [0], 0/2 -> 1/2 [0], 0/3 -> 1/3 [0]]'

media-ctl -d /dev/media0 -V '"os08a20 2-0036":0/0 [fmt:SBGGR10/3840x2160 field:none]'
media-ctl -d /dev/media0 -V '"csidev-4ad30000.csi":0/0 [fmt:SBGGR10/3840x2160 field:none]'
media-ctl -d /dev/media0 -V '"4ac10000.syscon:formatter@20":0/0 [fmt:SBGGR10/3840x2160 field:none]'
media-ctl -d /dev/media0 -V '"crossbar":2/0 [fmt:SBGGR10/3840x2160 field:none]'
media-ctl -d /dev/media0 -V '"mxc_isi.0":0/0 [fmt:SBGGR10/3840x2160 field:none]'

NODE="$(media-ctl -e 'mxc_isi.0.capture' -d /dev/media0 | head -n1)"
v4l2-ctl -d "$NODE" --set-fmt-video=width=3840,height=2160,pixelformat=BG10
 
echo "Media pipeline Set, Video Device Node" $NODE
