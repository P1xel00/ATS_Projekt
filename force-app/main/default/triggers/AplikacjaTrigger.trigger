trigger AplikacjaTrigger on Aplikacja__c (after insert, after delete) {
    AplikacjaTriggerHandler.run(Trigger.new, Trigger.old, Trigger.isAfter, Trigger.isInsert, Trigger.isDelete);
}
