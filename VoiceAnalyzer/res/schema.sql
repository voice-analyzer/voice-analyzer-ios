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
);

CREATE TABLE analysis (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
    , "recordingId" INTEGER NOT NULL
    , "pitchEstimationAlgorithm" INTEGER
    , "formantEstimationAlgorithm" INTEGER
    , "lowerLimitLine" REAL
    , "upperLimitLine" REAL
);

CREATE INDEX analysisRecordingId ON analysis (
    "recordingId"
);

CREATE TABLE analysisFrame (
    "analysisId" INTEGER NOT NULL
    , "time" REAL NOT NULL
    , "pitchFrequency" REAL
    , "pitchConfidence" REAL
    , "firstFormantFrequency" REAL
    , "secondFormantFrequency" REAL
    , PRIMARY KEY("analysisId", "time" ASC)
);
