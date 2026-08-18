@echo off
cd /d C:\Users\Nachireddy\Downloads\freeloop-source\lms-platform\backend
mvn -o compile -DskipTests 2>&1
echo MVN_EXIT_CODE=%ERRORLEVEL%
