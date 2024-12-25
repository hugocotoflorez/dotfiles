#!/bin/bash

# Obtén el directorio activo de la ventana enfocada
current_dir=$(pwd)

# Si no se puede obtener el directorio, usa el HOME como fallback
current_dir=${current_dir:-$HOME}

# Abre la terminal en el directorio correcto
kitty --class floating_terminal -d "$current_dir"

