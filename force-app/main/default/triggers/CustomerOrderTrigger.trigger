trigger CustomerOrderTrigger on DUET__Customer_Order__c (before insert, before update) {
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        CustomerOrderTriggerHandler.handleBeforeInsertUpdate(Trigger.new);
    }
}
