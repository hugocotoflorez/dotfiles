#!/bin/bash
history -1 | cut -d -f 4- | xargs sudo
