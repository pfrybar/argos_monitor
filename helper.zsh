WHITE="#ffffff"
GREEN="#b5bd68"
YELLOW="#f0c674"
RED="#cc6666"
ORANGE="#de935f"
CYAN="#8abeb7"
BLUE="#81a2be"
PURPLE="#b294bb"
BROWN="#a3685a"

function human_readable {
    b=$1
    s=1
    S=({B,KB,MB,GB,TB,EB,PB,YB,ZB})
    while (($b > 1024)); do
        b=$(($b / 1024.))
        s=$((s+1))
    done
    echo "$(printf '%.2f' $b) ${S[$s]}"
}
