ALTER TABLE dbo.Widget
    ADD Price decimal(10,2) NOT NULL
        CONSTRAINT DF_Widget_Price DEFAULT (0);
GO

CREATE INDEX IX_Widget_Name ON dbo.Widget (Nmae);
