CREATE TABLE skippedMigration (
    "migrationId" TEXT NOT NULL UNIQUE PRIMARY KEY
);

CREATE TABLE recording (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
    , "name" TEXT
    , "timestamp" INTEGER NOT NULL
    , "length" REAL NOT NULL
    , "filename" TEXT
    , "fileSize" INTEGER
)
