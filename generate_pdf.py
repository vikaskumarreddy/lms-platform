import gzip

pdf_lines = [
    "%PDF-1.4",
    "1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj",
    "2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj",
    "3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> >> endobj",
    "4 0 obj << /Length 640 >> stream",
    "BT",
    "/F1 20 Tf 50 720 Td (Java Fundamentals - Lesson 01: Introduction) Tj",
    "/F2 12 Tf 0 -35 Td (Welcome to Axisora Forge Academy. In this lesson, we cover core Java fundamentals.) Tj",
    "0 -25 Td (1. What is Java and How Does it Work?) Tj",
    "0 -18 Td (   - Java is a high-level, class-based, object-oriented language.) Tj",
    "0 -18 Td (   - Write Once, Run Anywhere (WORA) via the Java Virtual Machine (JVM).) Tj",
    "0 -25 Td (2. Key Components of Java Architecture:) Tj",
    "0 -18 Td (   - JDK (Java Development Kit): Compiler, debugger, core tools.) Tj",
    "0 -18 Td (   - JRE (Java Runtime Environment): Libraries + JVM to execute code.) Tj",
    "0 -18 Td (   - JVM (Java Virtual Machine): Executes bytecode on hardware.) Tj",
    "0 -25 Td (3. Core Data Types and Variables:) Tj",
    "0 -18 Td (   - Primitives: byte, short, int, long, float, double, boolean, char) Tj",
    "0 -18 Td (   - Reference types: String, Arrays, Classes, Interfaces) Tj",
    "0 -30 Td (Practice coding exercises and quizzes in the assessment module.) Tj",
    "ET",
    "endstream endobj",
    "5 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >> endobj",
    "6 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj",
    "xref",
    "0 7",
    "0000000000 65535 f ",
    "0000000009 00000 n ",
    "0000000058 00000 n ",
    "0000000115 00000 n ",
    "0000000266 00000 n ",
    "0000000958 00000 n ",
    "0000001035 00000 n ",
    "trailer << /Size 7 /Root 1 0 R >>",
    "startxref",
    "1107",
    "%%EOF"
]

pdf_data = "\n".join(pdf_lines).encode("latin1")
with open("lesson_sample.pdf", "wb") as f:
    f.write(pdf_data)

with gzip.open("media-intro-programming.bin.gz", "wb") as f:
    f.write(pdf_data)

print(f"Successfully generated PDF: {len(pdf_data)} bytes")
