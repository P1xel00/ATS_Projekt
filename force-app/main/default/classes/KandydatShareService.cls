public without sharing class KandydatShareService {

    private static final String RC_CAND_FOR_MGR = Schema.Kandydat__Share.RowCause.Menedzer_rekrutujacy__c;

    private static String key(Id a, Id b){ return (String)a + '|' + (String)b; }

    public static void syncForApplications(List<Aplikacja__c> insertApps, List<Aplikacja__c> deleteApps){

        Set<Id> offerIds = new Set<Id>();
        Set<Id> candIds  = new Set<Id>();

        if (insertApps != null) {
            for (Aplikacja__c a : insertApps) {
                if (a.Oferta_pracy__c != null) offerIds.add(a.Oferta_pracy__c);
                if (a.Kandydat__c != null)     candIds.add(a.Kandydat__c);
            }
        }
        if (deleteApps != null) {
            for (Aplikacja__c a : deleteApps) {
                if (a.Oferta_pracy__c != null) offerIds.add(a.Oferta_pracy__c);
                if (a.Kandydat__c != null)     candIds.add(a.Kandydat__c);
            }
        }
        if (offerIds.isEmpty() && candIds.isEmpty()) return;

        Map<Id, Id> mgrByOffer = new Map<Id, Id>();
        for (Oferta_Pracy__c o : [
            SELECT Id, Menedzer_rekrutujacy__c
            FROM Oferta_Pracy__c
            WHERE Id IN :offerIds
        ]) mgrByOffer.put(o.Id, o.Menedzer_rekrutujacy__c);

        Map<Id, Id> candOwnerById = new Map<Id, Id>();
        if (!candIds.isEmpty()){
            for (Kandydat__c c : [SELECT Id, OwnerId FROM Kandydat__c WHERE Id IN :candIds]){
                candOwnerById.put(c.Id, c.OwnerId);
            }
        }

        if (insertApps != null && !insertApps.isEmpty()) {
            Set<String> needPairs = new Set<String>();
            Map<String, Id> pairCand = new Map<String, Id>();
            Map<String, Id> pairMgr  = new Map<String, Id>();

            for (Aplikacja__c a : insertApps) {
                Id cand = a.Kandydat__c;
                Id mgr  = mgrByOffer.get(a.Oferta_pracy__c);
                if (cand == null || mgr == null) continue;

                if (candOwnerById.get(cand) == mgr) continue;

                String k = key(cand, mgr);
                needPairs.add(k);
                pairCand.put(k, cand);
                pairMgr.put(k, mgr);
            }

            if (!needPairs.isEmpty()) {
                Map<String, Kandydat__Share> exist = new Map<String, Kandydat__Share>();
                for (Kandydat__Share s : [
                    SELECT Id, ParentId, UserOrGroupId, AccessLevel, RowCause
                    FROM Kandydat__Share
                    WHERE ParentId IN :pairCand.values()
                    AND UserOrGroupId IN :pairMgr.values()
                    AND RowCause = :RC_CAND_FOR_MGR
                ]) exist.put(key(s.ParentId, s.UserOrGroupId), s);

                List<Kandydat__Share> toInsert = new List<Kandydat__Share>();
                for (String k : needPairs) {
                    if (!exist.containsKey(k)) {
                        Kandydat__Share ns = new Kandydat__Share();
                        ns.ParentId      = pairCand.get(k);
                        ns.UserOrGroupId = pairMgr.get(k);
                        ns.AccessLevel   = 'Read';
                        ns.RowCause      = RC_CAND_FOR_MGR;
                        toInsert.add(ns);
                    }
                }
                if (!toInsert.isEmpty()) insert toInsert;
            }
        }

        if (deleteApps != null && !deleteApps.isEmpty()) {
            Set<String> delPairs = new Set<String>();
            Map<String, Id> pairCand = new Map<String, Id>();
            Map<String, Id> pairMgr  = new Map<String, Id>();

            for (Aplikacja__c a : deleteApps) {
                Id cand = a.Kandydat__c;
                Id mgr  = mgrByOffer.get(a.Oferta_pracy__c);
                if (cand == null || mgr == null) continue;
                String k = key(cand, mgr);
                delPairs.add(k);
                pairCand.put(k, cand);
                pairMgr.put(k, mgr);
            }

            if (!delPairs.isEmpty()) {
                Set<Id> candSet = new Set<Id>(pairCand.values());
                Set<Id> mgrSet  = new Set<Id>(pairMgr.values());

                Map<String, Integer> countByPair = new Map<String, Integer>();
                for (AggregateResult ar : [
                    SELECT Kandydat__c c, Oferta_pracy__r.Menedzer_rekrutujacy__c m, COUNT(Id) cnt
                    FROM Aplikacja__c
                    WHERE Kandydat__c IN :candSet
                      AND Oferta_pracy__r.Menedzer_rekrutujacy__c IN :mgrSet
                    GROUP BY Kandydat__c, Oferta_pracy__r.Menedzer_rekrutujacy__c
                ]) {
                    String k = key((Id)ar.get('c'), (Id)ar.get('m'));
                    countByPair.put(k, (Integer)ar.get('cnt'));
                }

                List<Kandydat__Share> toDelete = new List<Kandydat__Share>();
                for (String k : delPairs) {
                    Integer cnt = countByPair.get(k);
                    if (cnt == null || cnt == 0) {
                        Id cand = pairCand.get(k);
                        Id mgr  = pairMgr.get(k);
                        for (Kandydat__Share s : [
                            SELECT Id
                            FROM Kandydat__Share
                            WHERE ParentId = :cand
                              AND UserOrGroupId = :mgr
                              AND RowCause = :RC_CAND_FOR_MGR
                        ]) toDelete.add(s);
                    }
                }
                if (!toDelete.isEmpty()) delete toDelete;
            }
        }
    }

    public static void syncForOffers(List<Oferta_Pracy__c> offers){ syncForOffers(offers, null); }

    public static void syncForOffers(List<Oferta_Pracy__c> offers, Map<Id, Oferta_Pracy__c> oldMap){
        if (offers == null || offers.isEmpty()) return;

        Set<Id> offerIds = new Set<Id>();
        Map<Id, Id> newMgrByOffer = new Map<Id, Id>();
        Map<Id, Id> oldMgrByOffer = new Map<Id, Id>();

        for (Oferta_Pracy__c o : offers){
            offerIds.add(o.Id);
            newMgrByOffer.put(o.Id, o.Menedzer_rekrutujacy__c);
            if (oldMap != null && oldMap.containsKey(o.Id)){
                oldMgrByOffer.put(o.Id, oldMap.get(o.Id).Menedzer_rekrutujacy__c);
            }
        }

        List<Aplikacja__c> apps = [
            SELECT Id, Kandydat__c, Oferta_pracy__c
            FROM Aplikacja__c
            WHERE Oferta_pracy__c IN :offerIds
        ];
        if (apps.isEmpty()) return;

        Set<Id> candSetAll = new Set<Id>();
        for (Aplikacja__c a : apps) if (a.Kandydat__c != null) candSetAll.add(a.Kandydat__c);
        Map<Id, Id> candOwnerById = new Map<Id, Id>();
        if (!candSetAll.isEmpty()){
            for (Kandydat__c c : [SELECT Id, OwnerId FROM Kandydat__c WHERE Id IN :candSetAll]){
                candOwnerById.put(c.Id, c.OwnerId);
            }
        }

        Set<String> addPairs = new Set<String>();
        Set<String> remPairs = new Set<String>();
        Map<String, Id> pairCand = new Map<String, Id>();
        Map<String, Id> pairMgr  = new Map<String, Id>();

        for (Aplikacja__c a : apps) {
            Id cand = a.Kandydat__c;
            Id offerId = a.Oferta_pracy__c;
            if (cand == null) continue;

            Id newMgr = newMgrByOffer.get(offerId);
            Id oldMgr = oldMgrByOffer.get(offerId);

            if (newMgr != null) {
                if (candOwnerById.get(cand) != newMgr) {
                    String k = key(cand, newMgr);
                    addPairs.add(k);
                    pairCand.put(k, cand);
                    pairMgr.put(k, newMgr);
                }
            }
            if (oldMgr != null && oldMgr != newMgr) {
                String k = key(cand, oldMgr);
                remPairs.add(k);
                pairCand.put(k, cand);
                pairMgr.put(k, oldMgr);
            }
        }

        if (!addPairs.isEmpty()){
            Map<String, Kandydat__Share> exist = new Map<String, Kandydat__Share>();
            for (Kandydat__Share s : [
                SELECT Id, ParentId, UserOrGroupId, RowCause
                FROM Kandydat__Share
                WHERE ParentId IN :pairCand.values()
                  AND UserOrGroupId IN :pairMgr.values()
                  AND RowCause = :RC_CAND_FOR_MGR
            ]) exist.put(key(s.ParentId, s.UserOrGroupId), s);

            List<Kandydat__Share> toInsert = new List<Kandydat__Share>();
            for (String k : addPairs){
                if (!exist.containsKey(k)) {
                    Kandydat__Share ns = new Kandydat__Share();
                    ns.ParentId      = pairCand.get(k);
                    ns.UserOrGroupId = pairMgr.get(k);
                    ns.AccessLevel   = 'Read';
                    ns.RowCause      = RC_CAND_FOR_MGR;
                    toInsert.add(ns);
                }
            }
            if (!toInsert.isEmpty()) insert toInsert;
        }

        if (!remPairs.isEmpty()){
            Set<Id> candSet = new Set<Id>();
            Set<Id> mgrSet  = new Set<Id>();
            for (String k : remPairs){
                candSet.add(pairCand.get(k));
                mgrSet.add(pairMgr.get(k));
            }

            Map<String, Integer> countByPair = new Map<String, Integer>();
            for (AggregateResult ar : [
                SELECT Kandydat__c c, Oferta_pracy__r.Menedzer_rekrutujacy__c m, COUNT(Id) cnt
                FROM Aplikacja__c
                WHERE Kandydat__c IN :candSet
                  AND Oferta_pracy__r.Menedzer_rekrutujacy__c IN :mgrSet
                GROUP BY Kandydat__c, Oferta_pracy__r.Menedzer_rekrutujacy__c
            ]) {
                String k = key((Id)ar.get('c'), (Id)ar.get('m'));
                countByPair.put(k, (Integer)ar.get('cnt'));
            }

            List<Kandydat__Share> toDelete = new List<Kandydat__Share>();
            for (String k : remPairs){
                Integer cnt = countByPair.get(k);
                if (cnt == null || cnt == 0) {
                    Id cand = pairCand.get(k);
                    Id mgr  = pairMgr.get(k);
                    for (Kandydat__Share s : [
                        SELECT Id
                        FROM Kandydat__Share
                        WHERE ParentId = :cand
                          AND UserOrGroupId = :mgr
                          AND RowCause = :RC_CAND_FOR_MGR
                    ]) toDelete.add(s);
                }
            }
            if (!toDelete.isEmpty()) delete toDelete;
        }
    }
}
