IF NOT EXISTS (SELECT 1 FROM dbo.SampleTable WHERE Id = 1)
BEGIN
    INSERT INTO dbo.SampleTable (Id, Name) VALUES (1, 'Seed Data');
END