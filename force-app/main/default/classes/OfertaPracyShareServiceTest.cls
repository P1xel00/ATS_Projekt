@IsTest
private class OfertaPracyShareServiceTest {

    private static User mkUser(String alias, String email) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        return new User(
            Alias = alias,
            Email = email,
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Europe/Warsaw',
            Username = email + '.' + System.currentTimeMillis()
        ,   ProfileId = p.Id
        );
    }

    @IsTest
    static void testCreateUpdateDeleteSharing() {
        User hr   = mkUser('hruser', 'hr@example.com');
        User mng1 = mkUser('mngone', 'm1@example.com');
        User mng2 = mkUser('mngtwo', 'm2@example.com');
        insert new List<User>{ hr, mng1, mng2 };

        Oferta_Pracy__c offer;
        System.runAs(hr){
            offer = new Oferta_Pracy__c(
                Tytul__c = 'Testowa',
                Menedzer_rekrutujacy__c = mng1.Id
            );
            insert offer;
        }

        Oferta_Pracy__Share s1 = [
            SELECT Id, AccessLevel, RowCause, UserOrGroupId
            FROM Oferta_Pracy__Share
            WHERE ParentId = :offer.Id
              AND RowCause = :Schema.Oferta_Pracy__Share.RowCause.Menedzer_rekrutujacy__c
              AND UserOrGroupId = :mng1.Id
            LIMIT 1
        ];
        System.assertEquals('Edit', s1.AccessLevel);

        System.runAs(hr){
            offer.Menedzer_rekrutujacy__c = mng2.Id;
            update offer;
        }

        System.assertEquals(0, [
            SELECT count()
            FROM Oferta_Pracy__Share
            WHERE ParentId = :offer.Id
              AND RowCause = :Schema.Oferta_Pracy__Share.RowCause.Menedzer_rekrutujacy__c
              AND UserOrGroupId = :mng1.Id
        ]);

        System.assertEquals(1, [
            SELECT count()
            FROM Oferta_Pracy__Share
            WHERE ParentId = :offer.Id
              AND RowCause = :Schema.Oferta_Pracy__Share.RowCause.Menedzer_rekrutujacy__c
              AND UserOrGroupId = :mng2.Id
        ]);

        System.runAs(hr){
            offer.Menedzer_rekrutujacy__c = null;
            update offer;
        }

        System.assertEquals(0, [
            SELECT count()
            FROM Oferta_Pracy__Share
            WHERE ParentId = :offer.Id
              AND RowCause = :Schema.Oferta_Pracy__Share.RowCause.Menedzer_rekrutujacy__c
        ]);
    }

    @IsTest
    static void testSkipShareForOwner() {
        User ownerAndManager = mkUser('ownerm', 'om@example.com');
        insert ownerAndManager;

        System.runAs(ownerAndManager){
            Oferta_Pracy__c o = new Oferta_Pracy__c(
                Tytul__c = 'Testowa',
                Menedzer_rekrutujacy__c = ownerAndManager.Id
            );
            insert o;
            
            System.assertEquals(0, [
                SELECT count()
                FROM Oferta_Pracy__Share
                WHERE ParentId = :o.Id
                  AND RowCause = :Schema.Oferta_Pracy__Share.RowCause.Menedzer_rekrutujacy__c
            ]);
        }
    }
}