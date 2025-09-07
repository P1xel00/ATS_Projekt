@IsTest
private class AtsAttentionApplicationsCtrlTest {

    private static Kandydat__c makeKandydat(String imie, String nazwisko, String email) {
        Kandydat__c k = new Kandydat__c();
        k.Imie__c = imie;
        k.Nazwisko__c = nazwisko;
        k.Email__c = email;
        insert k;
        return k;
    }

    private static Oferta_pracy__c makeOferta(String tytul, String status) {
        Oferta_pracy__c o = new Oferta_pracy__c();
        o.Tytul__c = tytul;
        o.Status__c = status;
        o.Data_publikacji__c = Date.today().addDays(-60);
        insert o;
        return o;
    }

    private static Aplikacja__c makeAplikacja(
        Kandydat__c k, Oferta_pracy__c o, String status, Date dataZgl, String zrodlo
    ) {
        Aplikacja__c a = new Aplikacja__c();
        a.Kandydat__c = k.Id;
        a.Oferta_pracy__c = o.Id;
        a.Status__c = status;
        a.Data_zgloszenia__c = dataZgl;
        a.Zrodlo_aplikacji__c = zrodlo;
        insert a;
        return a;
    }

    private static Etap_rekrutacji__c makeOpenEtap(Aplikacja__c app, String nazwa, Date start) {
        Etap_rekrutacji__c e = new Etap_rekrutacji__c();
        e.Aplikacja__c = app.Id;
        e.Nazwa_etapu__c = nazwa;
        e.Data_rozpoczecia__c = start;
        insert e;
        return e;
    }

    @IsTest
    static void testDefaultAgeDays_sorting_and_anchors() {
        Date today = Date.today();

        Kandydat__c k = makeKandydat('Jan', 'Kowalski', 'jan.kowalski@example.com');
        Oferta_pracy__c o = makeOferta('Developer', 'Aktywna');

        Aplikacja__c a1 = makeAplikacja(k, o, 'Nowa', today.addDays(-10), 'LinkedIn');

        Aplikacja__c a2 = makeAplikacja(k, o, 'W trakcie', today.addDays(-30), 'LinkedIn');
        Etap_rekrutacji__c e2Open = makeOpenEtap(a2, 'Rozmowa HR', today.addDays(-3));

        Aplikacja__c a3 = makeAplikacja(k, o, 'W trakcie', today.addDays(-40), 'LinkedIn');
        Etap_rekrutacji__c e3Open = makeOpenEtap(a3, 'Rozmowa HR', today.addDays(-15));

        Aplikacja__c a4 = makeAplikacja(k, o, 'Zakończona', today.addDays(-25), 'LinkedIn');

        Aplikacja__c a5 = makeAplikacja(k, o, 'Nowa', today.addDays(-20), 'LinkedIn');

        Test.startTest();
        List<AtsAttentionApplicationsCtrl.AppRow> rows =
            AtsAttentionApplicationsCtrl.getAttentionApps(null);
        Test.stopTest();

        System.assertEquals(3, rows.size(), 'Powinny wrócić 3 rekordy (A5,A3,A1).');

        System.assertEquals(a5.Id, rows[0].id, 'Pierwszy powinien być A5 (20 dni).');
        System.assertEquals(Integer.valueOf(20), rows[0].idleDays, 'A5 idleDays = 20');
        System.assertEquals(a5.Data_zgloszenia__c, rows[0].anchorDate, 'A5 anchor = data zgłoszenia');
        System.assertEquals('Nowa', rows[0].status, 'A5 status = Nowa');
        System.assertEquals(o.Tytul__c, rows[0].ofertaTitle, 'A5 ofertaTitle zgodny');
        System.assertEquals(k.Id, rows[0].kandydatId, 'A5 kandydatId zgodny');

        System.assertEquals(a3.Id, rows[1].id, 'Drugi powinien być A3 (15 dni).');
        System.assertEquals(Integer.valueOf(15), rows[1].idleDays, 'A3 idleDays = 15');
        System.assertEquals(e3Open.Data_rozpoczecia__c, rows[1].anchorDate, 'A3 anchor = start etapu');
        System.assertEquals('Rozmowa HR', rows[1].currentStageName, 'A3 bieżący etap = Rozmowa HR');

        System.assertEquals(a1.Id, rows[2].id, 'Trzeci powinien być A1 (10 dni).');
        System.assertEquals(Integer.valueOf(10), rows[2].idleDays, 'A1 idleDays = 10');
        System.assertEquals(a1.Data_zgloszenia__c, rows[2].anchorDate, 'A1 anchor = data zgłoszenia');

        for (AtsAttentionApplicationsCtrl.AppRow r : rows) {
            System.assert(r.id != a2.Id, 'A2 nie powinien się pojawić (byt świeży etap).');
            System.assert(r.id != a4.Id, 'A4 nie powinien się pojawić (status Zakończona).');
        }
    }

    @IsTest
    static void testWithCustomAgeDays() {
        Date today = Date.today();

        Kandydat__c k = makeKandydat('Anna', 'Nowak', 'anna.nowak@example.com');
        Oferta_pracy__c o = makeOferta('QA Engineer', 'Aktywna');

        Aplikacja__c a1 = makeAplikacja(k, o, 'Nowa', today.addDays(-10), 'LinkedIn');

        Aplikacja__c a2 = makeAplikacja(k, o, 'W trakcie', today.addDays(-30), 'LinkedIn');
        Etap_rekrutacji__c e2 = makeOpenEtap(a2, 'Rozmowa HR', today.addDays(-15));

        Aplikacja__c a3 = makeAplikacja(k, o, 'Nowa', today.addDays(-20), 'LinkedIn');

        Test.startTest();
        List<AtsAttentionApplicationsCtrl.AppRow> rows =
            AtsAttentionApplicationsCtrl.getAttentionApps(12);
        Test.stopTest();

        System.assertEquals(2, rows.size(), 'Dla ageDays=12 powinny wrócić 2 rekordy.');
        System.assertEquals(a3.Id, rows[0].id, 'Pierwszy powinien być A3 (20 dni).');
        System.assertEquals(Integer.valueOf(20), rows[0].idleDays);
        System.assertEquals(a2.Id, rows[1].id, 'Drugi powinien być A2 (15 dni).');
        System.assertEquals(Integer.valueOf(15), rows[1].idleDays);

        System.assertEquals(a3.Data_zgloszenia__c, rows[0].anchorDate);
        System.assertEquals(e2.Data_rozpoczecia__c, rows[1].anchorDate);
    }

    @IsTest
    static void testVeryHighAgeDays_NoResults() {
        Date today = Date.today();

        Kandydat__c k = makeKandydat('Piotr', 'Zielinski', 'piotr.z@example.com');
        Oferta_pracy__c o = makeOferta('PM', 'Aktywna');

        Aplikacja__c a1 = makeAplikacja(k, o, 'Nowa', today.addDays(-10), 'LinkedIn');
        Aplikacja__c a2 = makeAplikacja(k, o, 'W trakcie', today.addDays(-60), 'LinkedIn');
        makeOpenEtap(a2, 'Rozmowa HR', today.addDays(-20));

        Test.startTest();
        List<AtsAttentionApplicationsCtrl.AppRow> rows =
            AtsAttentionApplicationsCtrl.getAttentionApps(999);
        Test.stopTest();

        System.assertEquals(0, rows.size(), 'Przy ageDays=999 nic nie powinno wrócić.');
    }
}
