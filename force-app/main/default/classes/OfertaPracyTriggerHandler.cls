public with sharing class OfertaPracyTriggerHandler {
    public static void run(List<Oferta_Pracy__c> newList, Map<Id, Oferta_Pracy__c> oldMap, Boolean isInsert, Boolean isUpdate) {

        List<Oferta_Pracy__c> toProcess = new List<Oferta_Pracy__c>();
        for (Oferta_Pracy__c o : newList) {
            if (isInsert) {
                toProcess.add(o);
            } else if (isUpdate) {
                Oferta_Pracy__c oldO = oldMap.get(o.Id);
                if (o.Menedzer_rekrutujacy__c != oldO.Menedzer_rekrutujacy__c) {
                    toProcess.add(o);
                }
            }
        }

        if (!toProcess.isEmpty()) {
            OfertaPracyShareService.syncShares(toProcess, oldMap);
            KandydatShareService.syncForOffers(toProcess, oldMap);
        }
    }
}
