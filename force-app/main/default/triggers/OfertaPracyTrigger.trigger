trigger OfertaPracyTrigger on Oferta_Pracy__c (after insert, after update) {
    OfertaPracyTriggerHandler.run(Trigger.new, Trigger.oldMap, Trigger.isInsert, Trigger.isUpdate);
}