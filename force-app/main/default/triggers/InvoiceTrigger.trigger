trigger InvoiceTrigger on DUET__Invoice__c (before insert, before update) {
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        InvoiceTriggerHandler.handleBeforeInsertUpdate(Trigger.new);
    }
}
