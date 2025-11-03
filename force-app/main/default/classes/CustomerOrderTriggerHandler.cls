public class CustomerOrderTriggerHandler {

    public static void handleBeforeInsertUpdate(List<DUET__Customer_Order__c> newOrders) {
        // Collect all unique Salesperson_ID__c values
        Set<String> salesPersonIds = new Set<String>();
        Boolean hasNonBlankSalesPersonIds = false;

        for (DUET__Customer_Order__c order : newOrders) {
            if (String.isNotBlank(order.Salesperson_ID__c)) {
                salesPersonIds.add(order.Salesperson_ID__c);
                hasNonBlankSalesPersonIds = true;
            }
        }

        // If no salesperson IDs to process, clear all lookup fields and exit
        if (!hasNonBlankSalesPersonIds) {
            for (DUET__Customer_Order__c order : newOrders) {
                order.Sales_Person__c = null;
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

        // Update customer orders with matching User IDs
        for (DUET__Customer_Order__c order : newOrders) {
            if (String.isNotBlank(order.Salesperson_ID__c)) {
                String salesPersonId = order.Salesperson_ID__c.trim();
                if (salesPersonIdToUserId.containsKey(salesPersonId)) {
                    order.Sales_Person__c = salesPersonIdToUserId.get(salesPersonId);
                } else {
                    // Clear the lookup if no match found
                    order.Sales_Person__c = null;
                }
            } else {
                // Clear the lookup if Salesperson_ID__c is blank
                order.Sales_Person__c = null;
            }
        }
    }
}
