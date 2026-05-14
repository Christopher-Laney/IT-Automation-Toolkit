// Power Query starter queries for IT Automation Toolkit CSV outputs.
// Create a text parameter named ToolkitRoot that points at the repository root,
// or replace ToolkitRoot with a literal path such as "C:\Repos\IT-Automation-Toolkit".

let
    SourceRoot = ToolkitRoot,
    ReportFolder = SourceRoot & "\samples\reports\",

    LoadCsv = (fileName as text) as table =>
        let
            Source = Csv.Document(
                File.Contents(ReportFolder & fileName),
                [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]
            ),
            PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars = true])
        in
            PromotedHeaders,

    InactiveUsers = Table.TransformColumnTypes(
        LoadCsv("inactive_users.csv"),
        {
            {"UserPrincipalName", type text},
            {"DisplayName", type text},
            {"Department", type text},
            {"LastSignIn", type date},
            {"DaysInactive", Int64.Type},
            {"RecommendedAction", type text}
        }
    ),

    LocalAdmins = Table.TransformColumnTypes(
        LoadCsv("local_admins.csv"),
        {
            {"ComputerName", type text},
            {"AdminAccount", type text},
            {"AccountType", type text},
            {"Approved", type logical},
            {"Notes", type text}
        }
    ),

    IntuneCompliance = Table.TransformColumnTypes(
        LoadCsv("intune_compliance.csv"),
        {
            {"DeviceName", type text},
            {"UserPrincipalName", type text},
            {"OS", type text},
            {"ComplianceState", type text},
            {"LastCheckIn", type datetime},
            {"Issue", type text}
        }
    ),

    M365LicenseAudit = Table.TransformColumnTypes(
        LoadCsv("m365_license_audit.csv"),
        {
            {"SkuPartNumber", type text},
            {"Assigned", Int64.Type},
            {"Available", Int64.Type},
            {"ConsumedPercent", Percentage.Type},
            {"Recommendation", type text}
        }
    ),

    SslExpiry = Table.TransformColumnTypes(
        LoadCsv("ssl_expiry.csv"),
        {
            {"Endpoint", type text},
            {"Host", type text},
            {"Port", Int64.Type},
            {"Subject", type text},
            {"Issuer", type text},
            {"NotAfter", type date},
            {"DaysUntilExp", Int64.Type},
            {"Status", type text}
        }
    ),

    SystemHealth = Table.TransformColumnTypes(
        LoadCsv("system_health.csv"),
        {
            {"ComputerName", type text},
            {"Status", type text},
            {"CpuPercent", Int64.Type},
            {"MemoryUsedPercent", Int64.Type},
            {"DiskSummary", type text},
            {"TimestampUTC", type datetime}
        }
    )
in
    [
        InactiveUsers = InactiveUsers,
        LocalAdmins = LocalAdmins,
        IntuneCompliance = IntuneCompliance,
        M365LicenseAudit = M365LicenseAudit,
        SslExpiry = SslExpiry,
        SystemHealth = SystemHealth
    ]
