SET python_path=%~dp0..\.venv\Scripts\python.exe
SET filepath=%~dp0..\src\dayahead_alg.py
start "" %python_path% %filepath%
timeout /t 60