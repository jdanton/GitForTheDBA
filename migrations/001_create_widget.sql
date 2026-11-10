-- 001: the Widget table from demo 1 (plus its audit column), with a few rows
-- so later migrations have data to work against.
CREATE TABLE dbo.Widget
(
    WidgetId    int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Widget PRIMARY KEY,
    Name        nvarchar(100)     NOT NULL,
    CreatedUtc  datetime2(3)      NOT NULL CONSTRAINT DF_Widget_CreatedUtc DEFAULT SYSUTCDATETIME()
);
GO

INSERT dbo.Widget (Name)
VALUES (N'Sprocket'), (N'Gizmo'), (N'Doohickey');
