PICTURES="Pictures"

for p in `find $PICTURES -type f` ; do
        echo "- **$p**"
        echo "![$p]($p)"
done
