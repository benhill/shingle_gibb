trigger CaseTrigger on Case (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        CaseTriggerHandler.handleAfterUpdate(Trigger.oldMap, Trigger.newMap);
    }
}
