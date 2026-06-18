/*
    HRTrainingOps - Phase I
    Script : 06_certification_release_review.sql
    Purpose: HR review decisions for failed or expired certifications
    Depends: 03_training_requests.sql
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.CertificationReleaseReview', N'U') IS NULL
BEGIN
    CREATE TABLE HRTrainingOps.CertificationReleaseReview
    (
        ReviewID            INT IDENTITY(1, 1) NOT NULL,
        TrainingRequestID   INT                NOT NULL,
        ReviewDecision      NVARCHAR(30)       NOT NULL,
        ReviewNotes         NVARCHAR(500)      NULL,
        ReviewedBy          NVARCHAR(100)      NOT NULL,
        ReviewDate          DATETIME2(0)       NOT NULL
            CONSTRAINT DF_CertificationReleaseReview_ReviewDate DEFAULT (SYSDATETIME()),

        CONSTRAINT PK_CertificationReleaseReview
            PRIMARY KEY CLUSTERED (ReviewID),

        CONSTRAINT FK_CertificationReleaseReview_TrainingRequests
            FOREIGN KEY (TrainingRequestID)
            REFERENCES HRTrainingOps.TrainingRequests (TrainingRequestID),

        CONSTRAINT CK_CertificationReleaseReview_Decision
            CHECK (ReviewDecision IN (N'Re-Enroll', N'Waived', N'Terminated')),

        CONSTRAINT CK_CertificationReleaseReview_ReviewedBy_NotEmpty
            CHECK (LEN(LTRIM(RTRIM(ReviewedBy))) > 0)
    );

    PRINT 'Table HRTrainingOps.CertificationReleaseReview created.';
END
ELSE
BEGIN
    PRINT 'Table HRTrainingOps.CertificationReleaseReview already exists.';
END
GO
