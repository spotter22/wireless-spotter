

			_reset_gctest()
						{
							local x
							x="${4}"
							rm -rf "$x"
							mkdir "$x"
							touch "$x/.placeholder"
							git -C "$x" init
							git -C "$x" add .
							git -C "$x" config user.email "spotter24.t.me"
							git -C "$x" config user.name "${1}"
							git -C "$x" commit --author="${1} <spotter24.t.me>" -m "intial commit"
							git -C "$x" remote add origin "https://${1}:${2}@github.com/${1}/${3}.git"
							git -C "$x" push -f "https://${1}:${2}@github.com/${1}/${3}.git"
						}

