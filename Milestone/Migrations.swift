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

        migrator.registerMigration("v5_repair_template_schema_compat") { db in
            let now = DateISO8601.string(from: Date())

            if try db.tableExists("templates") {
                let templateColumnRows = try Row.fetchAll(db, sql: "PRAGMA table_info(templates)")
                let templateColumns = Set(templateColumnRows.compactMap { (row: Row) -> String? in
                    row["name"]
                })

                if !templateColumns.contains("created_at") {
                    try db.alter(table: "templates") { table in
                        table.add(column: "created_at", .text).notNull().defaults(to: now)
                    }
                }

                if !templateColumns.contains("updated_at") {
                    try db.alter(table: "templates") { table in
                        table.add(column: "updated_at", .text).notNull().defaults(to: now)
                    }
                }

                try db.execute(
                    sql: """
                    UPDATE templates
                    SET created_at = COALESCE(created_at, ?),
                        updated_at = COALESCE(updated_at, ?)
                    """,
                    arguments: [now, now]
                )
            } else {
                try db.create(table: "templates") { t in
                    t.column("id", .text).primaryKey()
                    t.column("name", .text).notNull()
                    t.column("description", .text)
                    t.column("created_at", .text).notNull()
                    t.column("updated_at", .text).notNull()
                }
            }

            let rebuiltTableName = "template_exercises_v5"
            if try db.tableExists(rebuiltTableName) {
                try db.drop(table: rebuiltTableName)
            }

            try db.create(table: rebuiltTableName) { t in
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

            if try db.tableExists("template_exercises") {
                let teColumnRows = try Row.fetchAll(db, sql: "PRAGMA table_info(template_exercises)")
                let teColumns = Set(teColumnRows.compactMap { (row: Row) -> String? in
                    row["name"]
                })

                func selectExpression(
                    target: String,
                    alternatives: [String] = [],
                    fallbackSQL: String = "NULL"
                ) -> String {
                    if teColumns.contains(target) {
                        return "\"\(target)\""
                    }
                    for alt in alternatives where teColumns.contains(alt) {
                        return "\"\(alt)\""
                    }
                    return fallbackSQL
                }

                let idExpr = selectExpression(
                    target: "id",
                    fallbackSQL: "lower(hex(randomblob(16)))"
                )
                let templateIDExpr = selectExpression(target: "template_id")
                let exerciseIDExpr = selectExpression(target: "exercise_id")
                let orderIndexExpr = selectExpression(
                    target: "order_index",
                    alternatives: ["order"],
                    fallbackSQL: "rowid"
                )
                let targetSetsExpr = selectExpression(target: "target_sets")
                let targetRepsExpr = selectExpression(target: "target_reps")
                let targetWeightExpr = selectExpression(target: "target_weight_kg")
                let targetDistanceExpr = selectExpression(target: "target_distance_m")
                let targetDurationExpr = selectExpression(target: "target_duration_sec")
                let notesExpr = selectExpression(target: "notes")
                let createdAtExpr = selectExpression(
                    target: "created_at",
                    fallbackSQL: "'\(now)'"
                )
                let updatedAtExpr = selectExpression(
                    target: "updated_at",
                    fallbackSQL: "'\(now)'"
                )

                try db.execute(sql: """
                    INSERT INTO \(rebuiltTableName) (
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
                        \(idExpr),
                        \(templateIDExpr),
                        \(exerciseIDExpr),
                        \(orderIndexExpr),
                        \(targetSetsExpr),
                        \(targetRepsExpr),
                        \(targetWeightExpr),
                        \(targetDistanceExpr),
                        \(targetDurationExpr),
                        \(notesExpr),
                        \(createdAtExpr),
                        \(updatedAtExpr)
                    FROM template_exercises
                    WHERE \(templateIDExpr) IS NOT NULL
                      AND \(exerciseIDExpr) IS NOT NULL
                    """)

                try db.drop(table: "template_exercises")
            }

            try db.rename(table: rebuiltTableName, to: "template_exercises")
            try db.create(
                index: "idx_template_exercises_template_id_order_index",
                on: "template_exercises",
                columns: ["template_id", "order_index"]
            )
        }

        migrator.registerMigration("v6_store_distance_as_kilometers") { db in
            if try db.tableExists("sets") {
                try db.execute(sql: """
                    UPDATE sets
                    SET distance_m = distance_m / 1000.0
                    WHERE distance_m IS NOT NULL
                    """)
            }

            if try db.tableExists("template_exercises") {
                try db.execute(sql: """
                    UPDATE template_exercises
                    SET target_distance_m = target_distance_m / 1000.0
                    WHERE target_distance_m IS NOT NULL
                    """)
            }
        }

        return migrator
    }
}
