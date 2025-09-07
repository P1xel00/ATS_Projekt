@IsTest
private class KandydatShareServiceTest {

    private static User mk(String alias, String email) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        return new User(
            Alias = alias,
            Email = email,
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Europe/Warsaw',
            Username = email + '.' + System.currentTimeMillis(),
            ProfileId = p.Id
        );
    }

    @IsTest
    static void shares_created_on_app_insert_and_removed_on_app_delete() {
        User hr  = mk('hr','hr@ex.com');
        User mgr = mk('mgr','mgr@ex.com');
        insert new List<User>{ hr, mgr };

        Kandydat__c k;
        Oferta_Pracy__c o;
        Aplikacja__c app;

        Test.startTest();
        System.runAs(hr){
            k = new Kandydat__c(Imie__c='Jan', Nazwisko__c='Kowalski');
            insert k;

            o = new Oferta_Pracy__c(Tytul__c='Dev', Menedzer_rekrutujacy__c=mgr.Id);
            insert o;

            app = new Aplikacja__c(
                Kandydat__c = k.Id,
                Oferta_pracy__c = o.Id,
                Status__c = 'Nowa',
                Data_zgloszenia__c = Date.today()
            );
            insert app;

            delete app;
        }
        Test.stopTest();

        System.assertEquals(0, [
            SELECT count() FROM Kandydat__Share
            WHERE ParentId = :k.Id
              AND RowCause = :Schema.Kandydat__Share.RowCause.Menedzer_rekrutujacy__c
              AND UserOrGroupId = :mgr.Id
        ]);
    }

    @IsTest
    static void share_moves_when_offer_manager_changes() {
        User hr = mk('hr2','hr2@ex.com');
        User m1 = mk('m1','m1@ex.com');
        User m2 = mk('m2','m2@ex.com');
        insert new List<User>{ hr, m1, m2 };

        Kandydat__c k;
        Oferta_Pracy__c o;
        Aplikacja__c app;

        Test.startTest();
        System.runAs(hr){
            k = new Kandydat__c(Imie__c='Anna', Nazwisko__c='Nowak');
            insert k;

            o = new Oferta_Pracy__c(Tytul__c='QA', Menedzer_rekrutujacy__c=m1.Id);
            insert o;

            app = new Aplikacja__c(
                Kandydat__c = k.Id,
                Oferta_pracy__c = o.Id,
                Status__c = 'Nowa',
                Data_zgloszenia__c = Date.today()
            );
            insert app;

            System.assertEquals(1, [
                SELECT count() FROM Kandydat__Share
                WHERE ParentId = :k.Id
                  AND UserOrGroupId = :m1.Id
                  AND RowCause = :Schema.Kandydat__Share.RowCause.Menedzer_rekrutujacy__c
            ]);

            o.Menedzer_rekrutujacy__c = m2.Id;
            update o;
        }
        Test.stopTest();

        System.assertEquals(0, [
            SELECT count() FROM Kandydat__Share
            WHERE ParentId = :k.Id
              AND UserOrGroupId = :m1.Id
              AND RowCause = :Schema.Kandydat__Share.RowCause.Menedzer_rekrutujacy__c
        ]);
        System.assertEquals(1, [
            SELECT count() FROM Kandydat__Share
            WHERE ParentId = :k.Id
              AND UserOrGroupId = :m2.Id
              AND RowCause = :Schema.Kandydat__Share.RowCause.Menedzer_rekrutujacy__c
        ]);
    }

    @IsTest
    static void share_not_created_for_owner() {
        User u = mk('own','own@ex.com');
        insert u;

        Test.startTest();
        System.runAs(u){
            Kandydat__c k = new Kandydat__c(Imie__c='Ola', Nazwisko__c='Owner');
            insert k;

            Oferta_Pracy__c o = new Oferta_Pracy__c(Tytul__c='OwnerCase', Menedzer_rekrutujacy__c=u.Id);
            insert o;

            Aplikacja__c app = new Aplikacja__c(
                Kandydat__c = k.Id, Oferta_pracy__c = o.Id,
                Status__c='Nowa', Data_zgloszenia__c=Date.today()
            );
            insert app;

            System.assertEquals(0, [
                SELECT count() FROM Kandydat__Share
                WHERE ParentId = :k.Id
                  AND RowCause = :Schema.Kandydat__Share.RowCause.Menedzer_rekrutujacy__c
            ]);
        }
        Test.stopTest();
    }
}
