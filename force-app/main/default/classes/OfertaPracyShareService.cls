public without sharing class OfertaPracyShareService {

    private static final String RC_RECR_MANAGER = Schema.Oferta_Pracy__Share.RowCause.Menedzer_rekrutujacy__c;

    public static void syncShares(List<Oferta_Pracy__c> offers, Map<Id, Oferta_Pracy__c> oldMap) {
        
        Set<Id> offerIds = new Set<Id>();
        Map<Id, Id> newMgrByOffer = new Map<Id, Id>();
        Map<Id, Id> oldMgrByOffer = new Map<Id, Id>();

        for (Oferta_Pracy__c o : offers) {
            offerIds.add(o.Id);
            newMgrByOffer.put(o.Id, o.Menedzer_rekrutujacy__c);
            if (oldMap != null && oldMap.containsKey(o.Id)) {
                oldMgrByOffer.put(o.Id, oldMap.get(o.Id).Menedzer_rekrutujacy__c);
            }
        }

        Map<Id, Id> ownerByOffer = new Map<Id, Id>();
        for (Oferta_Pracy__c o : [
            SELECT Id, OwnerId FROM Oferta_Pracy__c WHERE Id IN :offerIds
        ]) ownerByOffer.put(o.Id, o.OwnerId);

        Map<String, Oferta_Pracy__Share> existingByKey = new Map<String, Oferta_Pracy__Share>();
        for (Oferta_Pracy__Share s : [
            SELECT Id, ParentId, UserOrGroupId, AccessLevel, RowCause
            FROM Oferta_Pracy__Share
            WHERE ParentId IN :offerIds AND RowCause = :RC_RECR_MANAGER 
        ]) {
            existingByKey.put(shareKey(s.ParentId, s.UserOrGroupId), s);
        }

        List<Oferta_Pracy__Share> toInsert = new List<Oferta_Pracy__Share>();
        List<Oferta_Pracy__Share> toUpdate = new List<Oferta_Pracy__Share>();
        List<Oferta_Pracy__Share> toDelete = new List<Oferta_Pracy__Share>();

        for (Id offerId : offerIds) {
            Id newMgr = newMgrByOffer.get(offerId);
            Id oldMgr = oldMgrByOffer.containsKey(offerId) ? oldMgrByOffer.get(offerId) : null;

            if (oldMgr != null && oldMgr != newMgr) {
                Oferta_Pracy__Share oldShare = existingByKey.get(shareKey(offerId, oldMgr));
                if (oldShare != null) toDelete.add(oldShare);
            }

            if (newMgr != null && newMgr != ownerByOffer.get(offerId)) {
                String key = shareKey(offerId, newMgr);
                Oferta_Pracy__Share cur = existingByKey.get(key);
                if (cur == null) {
                    Oferta_Pracy__Share s = new Oferta_Pracy__Share();
                    s.ParentId = offerId;
                    s.UserOrGroupId = newMgr;
                    s.AccessLevel = 'Edit';
                    s.RowCause = RC_RECR_MANAGER;
                    toInsert.add(s);
                } else if (cur.AccessLevel != 'Edit') {
                    cur.AccessLevel = 'Edit';
                    toUpdate.add(cur);
                }
            }
        }

        if (!toDelete.isEmpty()) {
            delete toDelete;
        }
        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    private static String shareKey(Id parentId, Id userOrGroupId) {
        return (String)parentId + '|' + (String)userOrGroupId;
    }
}