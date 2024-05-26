#!/bin/bash

RC='\e[0m'
RED='\e[31m'
YELLOW='\e[33m'
GREEN='\e[32m'

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

checkEnv() {
    ## Check for requirements.
    REQUIREMENTS=('curl' 'groups' 'sudo')
    for req in "${REQUIREMENTS[@]}"; do
        if ! command_exists "$req"; then
            echo -e "${RED}To run me, you need: ${REQUIREMENTS[*]}${RC}"
            exit 1
        fi
    done

    ## Check Package Manager
    PACKAGEMANAGER=('apt' 'yum' 'dnf' 'pacman' 'zypper')
    for pgm in "${PACKAGEMANAGER[@]}"; do
        if command_exists "$pgm"; then
            PACKAGER="$pgm"
            echo -e "Using ${pgm}"
            break
        fi
    done

    if [ -z "$PACKAGER" ]; then
        echo -e "${RED}Can't find a supported package manager${RC}"
        exit 1
    fi

    ## Check if the current directory is writable.
    GITPATH="$(dirname "$(realpath "$0")")"
    if [[ ! -w "$GITPATH" ]]; then
        echo -e "${RED}Can't write to ${GITPATH}${RC}"
        exit 1
    fi

    ## Check SuperUser Group
    SUPERUSERGROUP=('wheel' 'sudo' 'root')
    for sug in "${SUPERUSERGROUP[@]}"; do
        if groups | grep -q "$sug"; then
            SUGROUP="$sug"
            echo -e "Super user group ${SUGROUP}"
            break
        fi
    done

    ## Check if member of the sudo group.
    if ! groups | grep -q "$SUGROUP"; then
        echo -e "${RED}You need to be a member of the sudo group to run me!${RC}"
        exit 1
    fi
}

installDepend() {
    ## Check for dependencies.
    DEPENDENCIES=('bash' 'bash-completion' 'tar' 'neovim' 'bat' 'tree' 'multitail' 'fastfetch')
    echo -e "${YELLOW}Installing dependencies...${RC}"
    if [[ $PACKAGER == "pacman" ]]; then
        if ! command_exists yay && ! command_exists paru; then
            echo "Installing yay as AUR helper..."
            sudo "$PACKAGER" --noconfirm -S base-devel
            cd /opt && sudo git clone https://aur.archlinux.org/yay-git.git && sudo chown -R "$USER:$USER" ./yay-git
            cd yay-git && makepkg --noconfirm -si
        else
            echo "AUR helper already installed"
        fi
        if command_exists yay; then
            AUR_HELPER="yay"
        elif command_exists paru; then
            AUR_HELPER="paru"
        else
            echo "No AUR helper found. Please install yay or paru."
            exit 1
        fi
        "$AUR_HELPER" --noconfirm -S "${DEPENDENCIES[@]}"
    else
        sudo "$PACKAGER" install -yq "${DEPENDENCIES[@]}"
    fi
}

installStarship() {
    if command_exists starship; then
        echo "Starship already installed"
        return
    fi

    if ! curl -sS https://starship.rs/install.sh | sh; then
        echo -e "${RED}Something went wrong during starship install!${RC}"
        exit 1
    fi
    if command_exists fzf; then
        echo "Fzf already installed"
    else
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install
    fi
}

installZoxide() {
    if command_exists zoxide; then
        echo "Zoxide already installed"
        return
    fi

    if ! curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh; then
        echo -e "${RED}Something went wrong during zoxide install!${RC}"
        exit 1
    fi
}

install_additional_dependencies() {
   sudo apt update
   sudo apt install -y trash-cli bat meld joe
}

linkConfig() {
    ## Get the correct user home directory.
    USER_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)
    ## Check if a bashrc file is already there.
    OLD_BASHRC="${USER_HOME}/.bashrc"
    if [[ -e "$OLD_BASHRC" ]]; then
        echo -e "${YELLOW}Moving old bash config file to ${USER_HOME}/.bashrc.bak${RC}"
        if ! mv "$OLD_BASHRC" "${USER_HOME}/.bashrc.bak"; then
            echo -e "${RED}Can't move the old bash config file!${RC}"
            exit 1
        fi
    fi

    echo -e "${YELLOW}Linking new bash config file...${RC}"
    ## Make symbolic link.
    ln -svf "${GITPATH}/.bashrc" "${USER_HOME}/.bashrc"
#    echo "ln -svf ${GITPATH}/.bashrc ${USER_HOME}/.bashrc"
#    echo "ln -svf ${GITPATH}/starship.toml ${USER_HOME}/.config/starship.toml" # see install_host_specific

echo $USER_HOME
echo $GITPATH

    mkdir ${USER_HOME}/.config
    ln -svf "${GITPATH}/starship.toml" "${USER_HOME}/.config/starship.toml"

    echo "host specific stuff for $HOSTNAME"
case $HOSTNAME in
    'RIGEL')
        echo 'specific installation for RIGEL'
        echo '   - exa, ls replacement '
	sudo apt update
	sudo apt install exa
	echo '   - starship'
        ln -svf ${GITPATH}/starship.toml.RIGEL ${USER_HOME}/.config/starship.toml
        ;;
    'add your here')
        ;;
    *)
        echo 'no host specific installation'
        ;;
esac
}

checkEnv
installDepend
installStarship
installZoxide
install_additional_dependencies
install_host_specific

if linkConfig; then
    echo -e "${GREEN}Done!\nrestart your shell to see the changes.${RC}"
else
    echo -e "${RED}Something went wrong!${RC}"
fi

