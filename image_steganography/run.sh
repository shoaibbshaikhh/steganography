#!/bin/bash

# Activate virtual environment
case "$(uname -s)" in
    Linux*|Darwin*)
        source venv/bin/activate
        ;;
    CYGWIN*|MINGW*|MSYS*)
        source venv/Scripts/activate
        ;;
    *)
        echo "Unable to detect OS for virtual environment activation. Please activate it manually."
        exit 1
        ;;
esac

# Start Django development server
python manage.py runserver
