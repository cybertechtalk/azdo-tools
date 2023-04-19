$DK_FO_Servers = [ordered]@{
    Prod    = @("L1");
    Staging = @("F1");
    Test    = @("C1", "C2");
}

$NO_SE_Servers = [ordered]@{
    Prod    = @("N1");
    Staging = @("E1");
    Test    = @("D1", "D2");
}

$countryServers = [ordered]@{
    "DK" = $DK_FO_Servers
    "FO" = $DK_FO_Servers
    "SE" = $NO_SE_Servers
    "NO" = $NO_SE_Servers
}