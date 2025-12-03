public class CaseTriggerHandler {

    public static void handleAfterUpdate(Map<Id, Case> oldCaseMap, Map<Id, Case> newCaseMap) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        // Collect all user IDs from case owners and case teams
        Set<Id> userIds = new Set<Id>();
        for (Case caseRecord : newCaseMap.values()) {
            userIds.add(caseRecord.OwnerId);
        }

        // Query case team members
        List<CaseTeamMember> caseTeamMembers = [
            SELECT MemberId, ParentId FROM CaseTeamMember WHERE ParentId IN :newCaseMap.keySet()
        ];
        for (CaseTeamMember ctm : caseTeamMembers) {
            userIds.add(ctm.MemberId);
        }

        // Query user emails
        Map<Id, String> userEmails = new Map<Id, String>();
        for (User u : [SELECT Id, Email FROM User WHERE Id IN :userIds]) {
            userEmails.put(u.Id, u.Email);
        }

        for (Id caseId : newCaseMap.keySet()) {
            Case oldCase = oldCaseMap.get(caseId);
            Case newCase = newCaseMap.get(caseId);

            List<FieldChange> changes = getFieldChanges(oldCase, newCase);

            if (!changes.isEmpty()) {
                // Get emails for case owner and team members
                Set<String> recipientEmails = new Set<String>();

                // Add case owner email
                if (userEmails.containsKey(newCase.OwnerId)) {
                    recipientEmails.add(userEmails.get(newCase.OwnerId));
                }

                // Add case team member emails
                for (CaseTeamMember ctm : caseTeamMembers) {
                    if (ctm.ParentId == caseId && userEmails.containsKey(ctm.MemberId)) {
                        recipientEmails.add(userEmails.get(ctm.MemberId));
                    }
                }

                if (!recipientEmails.isEmpty()) {
                    Messaging.SingleEmailMessage email = buildEmail(newCase, changes, new List<String>(recipientEmails));
                    emails.add(email);
                }
            }
        }

        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails);
            } catch (Exception e) {
                System.debug('Error sending case change notification email: ' + e.getMessage());
            }
        }
    }

    private static List<FieldChange> getFieldChanges(Case oldCase, Case newCase) {
        List<FieldChange> changes = new List<FieldChange>();

        // Get all fields from the Case object
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Case.fields.getMap();

        for (String fieldName : fieldMap.keySet()) {
            Schema.SObjectField field = fieldMap.get(fieldName);
            Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

            // Skip fields that are not updatable or accessible
            if (!fieldDescribe.isAccessible()) {
                continue;
            }

            Object oldValue = oldCase.get(fieldName);
            Object newValue = newCase.get(fieldName);

            // Check if the field value has changed
            if (hasChanged(oldValue, newValue)) {
                FieldChange change = new FieldChange();
                change.fieldLabel = fieldDescribe.getLabel();
                change.fieldName = fieldName;
                change.oldValue = formatValue(oldValue);
                change.newValue = formatValue(newValue);
                changes.add(change);
            }
        }

        return changes;
    }

    private static Boolean hasChanged(Object oldValue, Object newValue) {
        if (oldValue == null && newValue == null) {
            return false;
        }
        if (oldValue == null || newValue == null) {
            return true;
        }
        return !oldValue.equals(newValue);
    }

    private static String formatValue(Object value) {
        if (value == null) {
            return '(blank)';
        }
        if (value instanceof DateTime) {
            DateTime dt = (DateTime) value;
            return dt.format('yyyy-MM-dd HH:mm:ss');
        }
        if (value instanceof Date) {
            Date d = (Date) value;
            return String.valueOf(d);
        }
        return String.valueOf(value);
    }

    private static Messaging.SingleEmailMessage buildEmail(Case caseRecord, List<FieldChange> changes, List<String> recipientEmails) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();

        email.setToAddresses(recipientEmails);
        email.setSubject('Case Updated: ' + caseRecord.CaseNumber + ' - ' + (String.isNotBlank(caseRecord.Subject) ? caseRecord.Subject : 'No Subject'));

        String htmlBody = buildHtmlBody(caseRecord, changes);
        email.setHtmlBody(htmlBody);

        // Set plain text body as fallback
        String plainTextBody = buildPlainTextBody(caseRecord, changes);
        email.setPlainTextBody(plainTextBody);

        return email;
    }

    private static String buildHtmlBody(Case caseRecord, List<FieldChange> changes) {
        String orgUrl = URL.getOrgDomainUrl().toExternalForm();
        String caseLink = orgUrl + '/' + caseRecord.Id;

        String html = '<html><body>';
        html += '<h2>Case Updated</h2>';
        html += '<p><strong>Case Number:</strong> <a href="' + caseLink + '">' + caseRecord.CaseNumber + '</a></p>';
        html += '<p><strong>Subject:</strong> ' + (String.isNotBlank(caseRecord.Subject) ? caseRecord.Subject : 'No Subject') + '</p>';
        html += '<p><strong>Updated:</strong> ' + DateTime.now().format('yyyy-MM-dd HH:mm:ss') + '</p>';
        html += '<br/>';
        html += '<h3>Field Changes (' + changes.size() + ')</h3>';
        html += '<table border="1" cellpadding="8" cellspacing="0" style="border-collapse: collapse; font-family: Arial, sans-serif;">';
        html += '<thead><tr style="background-color: #f0f0f0;">';
        html += '<th>Field</th><th>Old Value</th><th>New Value</th>';
        html += '</tr></thead>';
        html += '<tbody>';

        for (FieldChange change : changes) {
            html += '<tr>';
            html += '<td><strong>' + change.fieldLabel + '</strong><br/><span style="color: #666; font-size: 11px;">' + change.fieldName + '</span></td>';
            html += '<td style="background-color: #ffe6e6;">' + change.oldValue + '</td>';
            html += '<td style="background-color: #e6ffe6;">' + change.newValue + '</td>';
            html += '</tr>';
        }

        html += '</tbody></table>';
        html += '</body></html>';

        return html;
    }

    private static String buildPlainTextBody(Case caseRecord, List<FieldChange> changes) {
        String orgUrl = URL.getOrgDomainUrl().toExternalForm();
        String caseLink = orgUrl + '/' + caseRecord.Id;

        String body = 'CASE UPDATED\n';
        body += '=============\n\n';
        body += 'Case Number: ' + caseRecord.CaseNumber + '\n';
        body += 'Subject: ' + (String.isNotBlank(caseRecord.Subject) ? caseRecord.Subject : 'No Subject') + '\n';
        body += 'Link: ' + caseLink + '\n';
        body += 'Updated: ' + DateTime.now().format('yyyy-MM-dd HH:mm:ss') + '\n\n';
        body += 'FIELD CHANGES (' + changes.size() + '):\n';
        body += '=============\n\n';

        for (FieldChange change : changes) {
            body += change.fieldLabel + ' (' + change.fieldName + '):\n';
            body += '  Old: ' + change.oldValue + '\n';
            body += '  New: ' + change.newValue + '\n\n';
        }

        return body;
    }

    private class FieldChange {
        String fieldLabel;
        String fieldName;
        String oldValue;
        String newValue;
    }
}
