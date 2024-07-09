GIT="$(git rev-parse --show-toplevel)"
echo "Git: $GIT"
REPO_PATH="$GIT/.config/nvim"
LOCAL_PATH="~/.config/nvim"
BACKUP_PATH="~/.config/nvim-legit"

if [[ ! -d "$REPO_PATH" ]]; then
    echo "nvim/ is not in repo folder!"
else
    echo "Nvim repo folder found"
    if [[ ! -d "$LOCAL_PATH" ]]; then
        echo "Not nvim/ path in .config"
        echo "Copying $REPO_PATH to $LOCAL_PATH"
        cp -r $REPO_PATH $LOCAL_PATH
    else
        echo "Local nvim in .config"
        if [[ ! -d "$BACKUP_PATH" ]]; then
            echo "Moving $LOCAL_PATH to $BACKUP_PATH"
            mv $LOCAL_PATH $BACKUP_PATH
            echo "Copying $REPO_PATH to $LOCAL_PATH"
            cp -r $REPO_PATH $LOCAL_PATH
        else
            echo "Delete manually $LOCAL_PATH or $BACKUP_PATH (not allowed to delete)"
        fi
    fi
fi
