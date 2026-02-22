import Foundation
import GRDB

enum Migrations {
    static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial_schema") { db in
            try db.create(table: "exercises") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("media_uri", .text)
                t.column("type", .text).notNull()
                t.column("description", .text)
                t.column("target_area", .text)
                t.column("is_archived", .integer).notNull().defaults(to: 0)
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
            }

            try db.create(table: "sessions") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text)
                t.column("start_datetime", .text).notNull()
                t.column("end_datetime", .text)
                t.column("notes", .text)
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
            }

            try db.create(table: "session_exercises") { t in
                t.column("id", .text).primaryKey()
                t.column("session_id", .text)
                    .notNull()
                    .references("sessions", onDelete: .cascade)
                t.column("exercise_id", .text)
                    .notNull()
                    .references("exercises", onDelete: .restrict)
                t.column("order_index", .integer).notNull()
                t.column("notes", .text)
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
            }

            try db.create(table: "sets") { t in
                t.column("id", .text).primaryKey()
                t.column("session_exercise_id", .text)
                    .notNull()
                    .references("session_exercises", onDelete: .cascade)
                t.column("set_index", .integer).notNull()
                t.column("metric_type", .text).notNull()
                t.column("reps", .integer)
                t.column("weight_kg", .double)
                t.column("distance_m", .double)
                t.column("duration_sec", .integer)
                t.column("comment", .text)
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
            }

            try db.create(table: "templates") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("description", .text)
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
            }

            try db.create(table: "template_exercises") { t in
                t.column("id", .text).primaryKey()
                t.column("template_id", .text)
                    .notNull()
                    .references("templates", onDelete: .cascade)
                t.column("exercise_id", .text)
                    .notNull()
                    .references("exercises", onDelete: .restrict)
                t.column("order_index", .integer).notNull()
                t.column("target_sets", .integer)
                t.column("target_reps", .integer)
                t.column("target_weight_kg", .double)
                t.column("target_distance_m", .double)
                t.column("target_duration_sec", .integer)
                t.column("notes", .text)
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
            }

            try db.create(table: "body_metrics") { t in
                t.column("id", .text).primaryKey()
                t.column("datetime", .text).notNull()
                t.column("bodyweight_kg", .double)
                t.column("bodyfat_pct", .double)
                t.column("notes", .text)
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
            }

            try db.create(index: "idx_session_exercises_session_id_order_index", on: "session_exercises", columns: ["session_id", "order_index"])
            try db.create(index: "idx_sets_session_exercise_id_set_index", on: "sets", columns: ["session_exercise_id", "set_index"])
            try db.create(index: "idx_template_exercises_template_id_order_index", on: "template_exercises", columns: ["template_id", "order_index"])
            try db.create(index: "idx_exercises_is_archived", on: "exercises", columns: ["is_archived"])
            try db.create(index: "idx_sessions_start_datetime", on: "sessions", columns: ["start_datetime"])
        }

        migrator.registerMigration("v2_add_exercise_category") { db in
            try db.alter(table: "exercises") { table in
                table.add(column: "exercise_category", .text)
            }
            try db.create(index: "idx_exercises_exercise_category", on: "exercises", columns: ["exercise_category"])
        }

        migrator.registerMigration("v3_add_exercise_source") { db in
            try db.alter(table: "exercises") { table in
                table.add(column: "exercise_source", .text).notNull().defaults(to: "user")
            }
            try db.create(index: "idx_exercises_exercise_source", on: "exercises", columns: ["exercise_source"])
        }

        migrator.registerMigration("v4_remove_rpe_and_rest_columns") { db in
            try db.create(table: "sets_v4") { t in
                t.column("id", .text).primaryKey()
                t.column("session_exercise_id", .text)
                    .notNull()
                    .references("session_exercises", onDelete: .cascade)
                t.column("set_index", .integer).notNull()
                t.column("metric_type", .text).notNull()
                t.column("reps", .integer)
                t.column("weight_kg", .double)
                t.column("distance_m", .double)
                t.column("duration_sec", .integer)
                t.column("comment", .text)
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
            }

            try db.execute(sql: """
                INSERT INTO sets_v4 (
                    id,
                    session_exercise_id,
                    set_index,
                    metric_type,
                    reps,
                    weight_kg,
                    distance_m,
                    duration_sec,
                    comment,
                    created_at,
                    updated_at
                )
                SELECT
                    id,
                    session_exercise_id,
                    set_index,
                    metric_type,
                    reps,
                    weight_kg,
                    distance_m,
                    duration_sec,
                    comment,
                    created_at,
                    updated_at
                FROM sets
                """)

            try db.drop(table: "sets")
            try db.rename(table: "sets_v4", to: "sets")
            try db.create(index: "idx_sets_session_exercise_id_set_index", on: "sets", columns: ["session_exercise_id", "set_index"])

            try db.create(table: "template_exercises_v4") { t in
                t.column("id", .text).primaryKey()
                t.column("template_id", .text)
                    .notNull()
                    .references("templates", onDelete: .cascade)
                t.column("exercise_id", .text)
                    .notNull()
                    .references("exercises", onDelete: .restrict)
                t.column("order_index", .integer).notNull()
                t.column("target_sets", .integer)
                t.column("target_reps", .integer)
                t.column("target_weight_kg", .double)
                t.column("target_distance_m", .double)
                t.column("target_duration_sec", .integer)
                t.column("notes", .text)
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
            }

            try db.execute(sql: """
                INSERT INTO template_exercises_v4 (
                    id,
                    template_id,
                    exercise_id,
                    order_index,
                    target_sets,
                    target_reps,
                    target_weight_kg,
                    target_distance_m,
                    target_duration_sec,
                    notes,
                    created_at,
                    updated_at
                )
                SELECT
                    id,
                    template_id,
                    exercise_id,
                    order_index,
                    target_sets,
                    target_reps,
                    target_weight_kg,
                    target_distance_m,
                    target_duration_sec,
                    notes,
                    created_at,
                    updated_at
                FROM template_exercises
                """)

            try db.drop(table: "template_exercises")
            try db.rename(table: "template_exercises_v4", to: "template_exercises")
            try db.create(index: "idx_template_exercises_template_id_order_index", on: "template_exercises", columns: ["template_id", "order_index"])
        }

        return migrator
    }
}
