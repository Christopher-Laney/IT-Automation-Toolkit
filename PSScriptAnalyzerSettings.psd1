@{
  Severity = @(
    'Error',
    'Warning'
  )

  ExcludeRules = @(
    # The toolkit intentionally uses descriptive PascalCase function names
    # that map to operational actions rather than approved PowerShell verbs.
    'PSUseApprovedVerbs'
  )

  Rules = @{
    PSUseConsistentIndentation = @{
      Enable = $true
      Kind = 'space'
      IndentationSize = 2
    }

    PSUseConsistentWhitespace = @{
      Enable = $true
      CheckInnerBrace = $true
      CheckOpenBrace = $true
      CheckOpenParen = $true
      CheckOperator = $true
      CheckPipe = $true
      CheckPipeForRedundantWhitespace = $true
      CheckSeparator = $true
    }

    PSUseCompatibleSyntax = @{
      Enable = $true
      TargetVersions = @(
        '7.2',
        '7.4'
      )
    }

    PSAvoidUsingConvertToSecureStringWithPlainText = @{
      Enable = $true
    }

    PSAvoidUsingPlainTextForPassword = @{
      Enable = $true
    }
  }
}
