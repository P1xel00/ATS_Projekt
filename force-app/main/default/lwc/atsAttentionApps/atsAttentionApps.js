import { LightningElement, wire, track } from 'lwc';
import getAttentionApps from '@salesforce/apex/AtsAttentionApplicationsCtrl.getAttentionApps';
import { updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const ACTIONS = [
    { label: "Ustaw 'W trakcie'", name: 'to_in_progress' },
    { label: 'Otwórz', name: 'open' }
];

export default class atsAttentionApps extends LightningElement {
    @track rows = [];
    @track error;
    loading = false;
    @track
    allRows = [];
    chunkSize = 15;
    nextIndex = 0;
    @track
    ageDays = 7;

    columns = [
        {
            label: 'Aplikacja',
            fieldName: 'appUrl',
            type: 'url',
            typeAttributes: { label: { fieldName: 'appNumber' }, target: '_blank' }
        },
        {
            label: 'Kandydat',
            fieldName: 'kandydatUrl',
            type: 'url',
            typeAttributes: { label: { fieldName: 'kandydatName' }, target: '_blank' }
        },
        { label: 'Oferta', fieldName: 'ofertaTitle' },
        { label: 'Status', fieldName: 'status' },
        { label: 'Bieżący etap', fieldName: 'currentStageName' },
        { label: 'Ostatnia aktywność', fieldName: 'anchorDate', type: 'date' },
        { label: 'Bezczynność [dni]', fieldName: 'idleDays', type: 'number' },
        { type: 'action', typeAttributes: { rowActions: ACTIONS } }
    ];

    get hasOverflow() {
        return this.allRows.length > this.chunkSize;
    }

    get tableWrapperClass() {
        return 'slds-p-horizontal_small slds-p-vertical_x-small ' + (this.hasOverflow ? 'table-wrap--scroll' : '');
    }

    @wire(getAttentionApps, { ageDays: '$ageDays' })
    wired({ data, error }) {
        if (data) {
            this.error = null;
            this.allRows = data.map(r => ({
                ...r,
                appUrl: '/' + r.id,
                kandydatUrl: r.kandydatId ? '/' + r.kandydatId : null
            }));
            this.resetPagination();
        } else if (error) {
            this.error = this.parseError(error);
            this.allRows = [];
            this.rows = [];
        }
    }

    handleAgeDaysChange = (e) => {
        const val = parseInt(e.target.value, 10);
        if (Number.isNaN(val)) {
            this.showToast('Błąd', 'Podaj liczbę całkowitą.', 'error');
            return;
        }
        if (val < 1) {
            this.showToast('Błąd', 'Wartość musi być ≥ 1.', 'error');
            return;
        }
        this.ageDays = val;
    };

    handleLoadMore = (event) => {
        if (this.nextIndex >= this.allRows.length) {
            event.target.isLoading = false;
            return;
        }
        const nextSlice = this.allRows.slice(this.nextIndex, this.nextIndex + this.chunkSize);
        this.rows = [...this.rows, ...nextSlice];
        this.nextIndex += nextSlice.length;
        event.target.isLoading = false;
    };

    resetPagination() {
        this.rows = [];
        this.nextIndex = 0;
        // Załaduj pierwszą porcję
        const first = this.allRows.slice(0, this.chunkSize);
        this.rows = first;
        this.nextIndex = first.length;
        this.loading = false;
    }

    async handleRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;

        if (action === 'open') {
            window.open('/' + row.id, '_blank');
            return;
        }

        if (action === 'to_in_progress') {
            try {
                this.loading = true;
                await updateRecord({
                    fields: { Id: row.id, Status__c: 'W trakcie' }
                });
                this.showToast('Sukces', 'Status zmieniony na „W trakcie”.', 'success');
                this.allRows = this.allRows.map(r => (r.id === row.id ? { ...r, status: 'W trakcie' } : r));
                this.rows = this.rows.map(r => (r.id === row.id ? { ...r, status: 'W trakcie' } : r));
            } catch (e) {
                this.showToast('Błąd', this.parseError(e), 'error');
            } finally {
                this.loading = false;
            }
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    parseError(e) {
        return (e && e.body && e.body.message) || e?.message || 'Nieznany błąd';
    }
}
