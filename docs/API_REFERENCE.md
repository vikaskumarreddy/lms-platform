# Axisora Forge Academy LMS - API Reference

## Authentication
- POST /api/auth/register - Register new user
- POST /api/auth/login - Login user

## Courses
- GET /api/courses - Get all courses
- GET /api/courses/{id} - Get course by ID
- POST /api/courses - Create course (Admin)
- PUT /api/courses/{id} - Update course (Admin). A metadata-only body (title, description, thumbnail, plan, instructor, isPublished) leaves the module/lesson tree untouched; modules are rebuilt only when the body includes a `modules` array.
- DELETE /api/courses/{id} - Delete course (Admin)

## Modules & lessons (admin portal)
- POST /api/modules/course/{courseId} - Add a module
- PUT /api/modules/{id} - Edit a module
- DELETE /api/modules/{id} - Delete a module and its lessons
- POST /api/modules/bulk-import/course/{courseId} - Bulk-create modules from a JSON or Excel upload (`multipart/form-data`, field `file`). Title and description are mandatory; rows without an order index get the next free one after the course's last module. Rows can carry nested lessons.
- POST /api/lessons/module/{moduleId} - Add a lesson
- PUT /api/lessons/{id} - Edit a lesson
- DELETE /api/lessons/{id} - Delete a lesson
- POST /api/lessons/bulk-import/module/{moduleId} - Bulk-create lessons from a JSON or Excel upload. An optional `moduleTitle` key / "Module" column routes a row to another module of the same course.

Both bulk-import endpoints answer with:

```json
{ "imported": 3, "lessonsImported": 0, "failed": 1,
  "errors": ["Row 4 (\"Advanced\"): Description is required."] }
```

Accepted inputs (max 500 rows per file):
- `application/json` - an array of objects (or an object wrapping a `modules`/`lessons` array) using the same field names as the manual forms; `order_index`-style keys and yes/no booleans are accepted too.
- Excel `.xlsx`/`.xls` - first sheet, first non-empty row is the header. Column names are matched ignoring case, spaces and underscores. In a module row an optional `Lessons` column may hold a JSON array.


## Dashboard
- GET /api/dashboard/stats - Get dashboard statistics

## Placements
- GET /api/placements - Get all placement drives
- GET /api/placements/{id} - Get placement drive by ID
- POST /api/placements - Create placement drive (Admin)

## Swagger UI
Full API documentation available at: http://localhost:8080/swagger-ui.html
