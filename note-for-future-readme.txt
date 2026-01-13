All dotfile packages are stowed from the the folder themselves.
Files that are undesired for git tracking must be declared in 
the root gitignore file. These files are things like current state values like,
symlinked layouts, currently applied colors etc.

The install will allow the user to either install with all the files symlinked to the repo clone
or locally copied to $HOME/.config/ this is because development is easier when everything is deployed out of the repo.
The local copy method is for actual deployment.

Might make a tool for the above that can compare the local install to a new version of the repo cloned to the system and 
show the user what is new and prompt them to install it. MAKE SURE current enviroment is left untouched as not to ruin their 
current setup.