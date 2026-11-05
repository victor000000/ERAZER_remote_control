@{
    # Deliberately small safety gate; formatting/style is not a migration gate.
    IncludeRules = @(
        'PSAvoidAssignmentToAutomaticVariable'
        'PSAvoidUsingInvokeExpression'
    )
    Severity = @('Error', 'Warning')
    # Syntax is checked separately with Parser.ParseFile, including archive/.
}
