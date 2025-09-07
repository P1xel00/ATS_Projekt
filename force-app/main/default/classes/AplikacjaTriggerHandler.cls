public with sharing class AplikacjaTriggerHandler {
    public static void run(
        List<Aplikacja__c> newList,
        List<Aplikacja__c> oldList,
        Boolean isAfter,
        Boolean isInsert,
        Boolean isDelete
    ){
        if (!isAfter) return;

        if (isInsert && newList != null && !newList.isEmpty()){
            KandydatShareService.syncForApplications(newList, null);
        }
        if (isDelete && oldList != null && !oldList.isEmpty()){
            KandydatShareService.syncForApplications(null, oldList);
        }
    }
}
