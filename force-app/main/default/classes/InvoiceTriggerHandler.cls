public class InvoiceTriggerHandler {

    public static void handleBeforeInsertUpdate(List<DUET__Invoice__c> newInvoices) {
        // Collect all unique Sales_Rep__c values
        Set<String> salesRepIds = new Set<String>();
        Boolean hasNonBlankSalesReps = false;

        for (DUET__Invoice__c invoice : newInvoices) {
            if (String.isNotBlank(invoice.Sales_Rep__c)) {
                salesRepIds.add(invoice.Sales_Rep__c);
                hasNonBlankSalesReps = true;
            }
        }

        // If no sales rep IDs to process, clear all lookup fields and exit
        if (!hasNonBlankSalesReps) {
            for (DUET__Invoice__c invoice : newInvoices) {
                invoice.Sales_Rep_Name__c = null;
            }
            return;
        }

        // Query all Users and build a map of salesperson IDs to User IDs
        // Need to handle semicolon-separated values in P21_Sales_Rep_ID__c
        Map<String, Id> salesPersonIdToUserId = new Map<String, Id>();

        List<User> users = [
            SELECT Id, P21_Sales_Rep_ID__c
            FROM User
            WHERE P21_Sales_Rep_ID__c != null
            AND IsActive = true
        ];

        // Parse each user's P21_Sales_Rep_ID__c field
        for (User u : users) {
            if (String.isNotBlank(u.P21_Sales_Rep_ID__c)) {
                // Check if it contains semicolons (multiple IDs)
                if (u.P21_Sales_Rep_ID__c.contains(';')) {
                    // Split by semicolon and trim whitespace
                    List<String> idList = u.P21_Sales_Rep_ID__c.split(';');
                    for (String salesPersonId : idList) {
                        String trimmedId = salesPersonId.trim();
                        if (String.isNotBlank(trimmedId)) {
                            salesPersonIdToUserId.put(trimmedId, u.Id);
                        }
                    }
                } else {
                    // Single value, no semicolon
                    salesPersonIdToUserId.put(u.P21_Sales_Rep_ID__c.trim(), u.Id);
                }
            }
        }

        // Update invoices with matching User IDs
        for (DUET__Invoice__c invoice : newInvoices) {
            if (String.isNotBlank(invoice.Sales_Rep__c)) {
                String salesRepId = invoice.Sales_Rep__c.trim();
                if (salesPersonIdToUserId.containsKey(salesRepId)) {
                    invoice.Sales_Rep_Name__c = salesPersonIdToUserId.get(salesRepId);
                } else {
                    // Clear the lookup if no match found
                    invoice.Sales_Rep_Name__c = null;
                }
            } else {
                // Clear the lookup if Sales_Rep__c is blank
                invoice.Sales_Rep_Name__c = null;
            }
        }
    }
}
