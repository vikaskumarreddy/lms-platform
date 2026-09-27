import os
import gzip
import tarfile

downloads = r"C:\Users\Nachireddy\Downloads"
mapping = {
    8: "Lesson_01_Introduction_to_Programming.pdf",
    9: "Lesson_02_Problem_Solving.pdf",
    10: "Lesson_03_Algorithm.pdf",
    11: "Lesson_04_Pseudocode.pdf",
    12: "Lesson_05_Flow_Charts.pdf",
    13: "M02_Lesson_03_Python_Execution.pdf",
    14: "M02_Lesson_05_Virtual_Environments.pdf",
    15: "M02_Lesson_04_Python_Installation.pdf",
    16: "M02_Lesson_02_Python_Implementations.pdf",
    17: "M02_Lesson_01_Python_Introduction.pdf",
    18: "M03_Lesson_01_Python_Syntax.pdf",
    19: "M03_Lesson_02_Comments.pdf",
    20: "M03_Lesson_03_Naming_Conventions.pdf",
    21: "M03_Lesson_04_Python_Keywords.pdf",
    22: "M04_Lesson_04_Mutable_vs_Immutable.pdf",
    23: "M04_Lesson_03_Python_Data_Types.pdf",
    24: "M04_Lesson_02_Objects.pdf",
    25: "M04_Lesson_01_Variables.pdf",
}

out_dir = "prepared_media"
os.makedirs(out_dir, exist_ok=True)
sql_lines = []

for mid, fname in sorted(mapping.items()):
    in_path = os.path.join(downloads, fname)
    with open(in_path, "rb") as f:
        raw_data = f.read()
    orig_size = len(raw_data)

    gz_filename = f"media-lesson-{mid}.bin.gz"
    out_path = os.path.join(out_dir, gz_filename)
    with gzip.open(out_path, "wb") as gf:
        gf.write(raw_data)
    gz_size = os.path.getsize(out_path)

    sql_lines.append(
        f"UPDATE media_items SET file_name = '{gz_filename}', mime_type = 'application/pdf', original_size = {orig_size}, stored_size = {gz_size} WHERE id = {mid};"
    )
    print(f"Processed ID {mid} ({fname}): raw={orig_size}B -> gz={gz_size}B as {gz_filename}")

with open(os.path.join(out_dir, "update_media.sql"), "w") as sf:
    sf.write("\n".join(sql_lines) + "\n")

with tarfile.open("all_lesson_media.tar.gz", "w:gz") as tar:
    tar.add(out_dir, arcname=".")

print("Successfully created all_lesson_media.tar.gz")
