from os import getcwd
from pathlib import Path

if __name__ == "__main__":
    for file in Path(getcwd()).glob("**/*"):
        if file.is_file():
            with file.open("rw") as file:
                data: str = file.read()
                file.write(data.replace("\r\n", "\n"))
