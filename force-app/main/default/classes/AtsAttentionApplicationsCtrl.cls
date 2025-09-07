public with sharing class AtsAttentionApplicationsCtrl {
    public class AppRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String appNumber;
        @AuraEnabled public String status;
        @AuraEnabled public Date dataZgloszenia;
        @AuraEnabled public Integer idleDays;
        @AuraEnabled public String currentStageName;
        @AuraEnabled public Date anchorDate;
        @AuraEnabled public Id kandydatId;
        @AuraEnabled public String kandydatName;
        @AuraEnabled public Id ofertaId;
        @AuraEnabled public String ofertaTitle;
    }

    @AuraEnabled(cacheable=true)
    public static List<AppRow> getAttentionApps(Integer ageDays) {
        Integer staleness = (ageDays == null || ageDays <= 0) ? 7 : ageDays;
        Date today = Date.today();

        List<Aplikacja__c> apps = [
            SELECT Id, Name, Status__c, Data_zgloszenia__c,
                   Kandydat__c, Kandydat__r.Name,
                   Oferta_pracy__c, Oferta_pracy__r.Tytul__c,
                   (SELECT Id, Nazwa_etapu__c, Data_rozpoczecia__c, Data_zakonczenia__c
                    FROM Etapy_rekrutacji__r
                    WHERE Data_zakonczenia__c = NULL
                    ORDER BY Data_rozpoczecia__c DESC
                    LIMIT 1)
            FROM Aplikacja__c
            WHERE Status__c IN ('Nowa','W trakcie')
            ORDER BY Data_zgloszenia__c ASC
        ];

        List<AppRow> rows = new List<AppRow>();
        for (Aplikacja__c a : apps) {
            Date anchor = a.Data_zgloszenia__c;
            String stageName;

            if (a.Etapy_rekrutacji__r != null && !a.Etapy_rekrutacji__r.isEmpty()) {
                Etap_rekrutacji__c openStage = a.Etapy_rekrutacji__r[0];
                stageName = openStage.Nazwa_etapu__c;
                if (openStage.Data_rozpoczecia__c != null) {
                    anchor = openStage.Data_rozpoczecia__c;
                }
            }

            Integer dwell = (anchor == null) ? null : Integer.valueOf(anchor.daysBetween(today));
            if (dwell != null && dwell >= staleness) {
                AppRow r = new AppRow();
                r.id = a.Id;
                r.appNumber = a.Name;
                r.status = a.Status__c;
                r.dataZgloszenia = a.Data_zgloszenia__c;
                r.idleDays = dwell;
                r.currentStageName = stageName;
                r.anchorDate = anchor;
                r.kandydatId = a.Kandydat__c;
                r.kandydatName = (a.Kandydat__r == null) ? null : a.Kandydat__r.Name;
                r.ofertaId = a.Oferta_pracy__c;
                r.ofertaTitle = (a.Oferta_pracy__r == null) ? null : a.Oferta_pracy__r.Tytul__c;
                rows.add(r);
            }
        }

        rows.sort(new ComparatorByIdleDesc());

        return rows;
    }

    public class ComparatorByIdleDesc implements System.Comparator<AppRow> {
        public Integer compare(AppRow a, AppRow b) {
            Integer ai = (a.idleDays == null) ? -1 : a.idleDays;
            Integer bi = (b.idleDays == null) ? -1 : b.idleDays;
            if (bi > ai) return 1;
            if (bi < ai) return -1;
            return 0;
        }
    }
}