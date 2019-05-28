/// <amd-module name='file-issue-form'/>


import Vue from "vue";
import VueResource from "vue-resource";
import Utils from "./utils";
// import Utils from "./utils";
// import UI from "./ui";
Vue.use(VueResource);
// import Utils from "./utils";
import RepresentationRequest from "./representation-linker";

interface QuoteLineItem {
    description: string;
    quantity: number;
    chargePerUnitCents: number;
    chargeQuantityUnit: string;
    chargeCents: number;
}

interface Quote {
    id: number;
    issuedDate: string;
    totalChargeCents: string;
    lineItems: QuoteLineItem[];
}

Vue.component('file-issue-form', {
    template: `
<div>
    <section id="items" class="scrollspy section card">
        <div class="card-content">
            <representation-linker input_path="file_issue_request[items][]" ref="linker" :representations="representations" :resolved_representations="resolved_representations" @change="refreshSummaries()" :readonly="readonly"></representation-linker>
        </div>
    </section>

    <slot></slot>

    <section id="digitalRequest" class="scrollspy section">
        <h4>Digital Request Summary</h4>
        <file-issue-request-summary ref="digitalRequest"
                                    :status="digital_request_status"
                                    :csrf_token="csrf_token"
                                    :request_id="request_id"
                                    request_type="digital"
                                    :quote_blob="digital_request_quote">
        </file-issue-request-summary>
    </section>

    <section id="physicalRequest" class="scrollspy section">
        <h4>Physical Request Summary</h4>
        <file-issue-request-summary ref="physicalRequest"
                                    :status="physical_request_status"
                                    :csrf_token="csrf_token"
                                    :request_id="request_id"
                                    :lock_version="lock_version"
                                    request_type="physical"
                                    :quote_blob="physical_request_quote">
        </file-issue-request-summary>
    </section>
</div>
`,
    data: function(): {readonly: boolean} {
        return {
            readonly: this.is_readonly === 'true',
        };
    },
    props: ['representations',
            'resolved_representations',
            'is_readonly',
            'digital_request_status',
            'physical_request_status',
            'csrf_token',
            'request_id',
            'lock_version',
            'digital_request_quote',
            'physical_request_quote'],
    methods: {
        refreshSummaries: function() {
            // FIXME type?
            const digitalRequest: any = this.$refs.digitalRequest;
            digitalRequest.syncItems(this.getDigitalRepresentations());
            const physicalRequest: any = this.$refs.physicalRequest;
            physicalRequest.syncItems(this.getPhysicalRepresentations());
        },
        getDigitalRepresentations: function() {
            // FIXME type?
            const linker: any = this.$refs.linker;
            return Utils.filter(linker.getSelected(), (rep: RepresentationRequest) => {
                return rep.requestType === 'DIGITAL';
            });
        },
        getPhysicalRepresentations: function() {
            // FIXME type?
            const linker: any = this.$refs.linker;
            return Utils.filter(linker.getSelected(), (rep: RepresentationRequest) => {
                return rep.requestType === 'PHYSICAL';
            });
        },
    },
    mounted: function() {
        this.refreshSummaries();
    },
});

Vue.component('file-issue-request-summary', {
    template: `
<div>
    <template v-if="items.length == 0">
        <div class="row">
            <div class="col s12 m6 l3">
                <div class="card-panel blue lighten-5">No {{request_type}} items requested.</div>
            </div>
        </div>
    </template>
    <template v-else>
        <div class="row">
            <div class="col s12">
                <a target="_blank" href="/file-issue-fee-schedule">View Fee Schedule</a>
            </div>
        </div>
        <h5>Items Requested</h5>
        <table>
            <thead>
                <tr>
                    <th style="width: 60px;">Series ID</th>
                    <th style="width: 60px;">Record ID</th>
                    <th>Title</th>
                    <th>Record Details</th>
                    <th style="width: 60px;">Representation ID</th>
                    <th style="width: 100px;">Format</th>
                    <th>Processing/<br>Handling Notes</th>
                </tr>
            </thead>
            <tbody>
                <tr v-for="representation in items">
                    <td>{{representation.metadata.series_id}}</td>
                    <td>{{representation.metadata.record_id}}</td>
                    <td>{{representation.metadata.title}}</td>
                    <td>{{representation.record_details}}</td>
                    <td>{{representation.metadata.representation_id}}</td>
                    <td>{{representation.metadata.format}}</td>
                    <td>{{representation.metadata.processing_handling_notes}}</td>
                </tr>
            </tbody>
        </table>
        <template v-if="quote != null">
            <h5>Quote</h5>
            <table>
                <thead>
                    <tr>
                        <th>Unit Description</th>
                        <th>Unit Cost</th>
                        <th>No. of Units</th>
                        <th>Cost</th>
                    </tr>
                </thead>
                <tbody>
                    <tr v-for="item in quote.lineItems">
                        <td>{{item.description}}</td>
                        <td>{{formatCents(item.chargePerUnitCents)}} per {{formatUnit(item.chargeQuantityUnit)}}</td>
                        <td>{{item.quantity}}</td>
                        <td class="right-align">{{formatCents(item.chargeCents)}}</td>
                    </tr>
                    <tr class="grey lighten-4">
                        <td colspan="3"><strong>TOTAL</strong></td>
                        <td class="right-align">{{formatCents(quote.totalChargeCents)}}</td>
                    </tr>
                </tbody>
            </table>
            <p>Issued: {{quote.issuedDate}}</p>
        </template>
        <template v-if="status === 'QUOTE_PROVIDED'">
            <div class="row">
                <div class="col s12">
                    <confirmable-action
                        :action="'/file-issue-requests/'+request_id+'/accept?request_type='+request_type+'&lock_version='+lock_version"
                        :csrf_token="csrf_token"
                        css="btn green lighten-2"
                        label="Accept Quote"
                        message="Are you sure you want to accept this quote?">
                    </confirmable-action>
                    <confirmable-action
                        :action="'/file-issue-requests/'+request_id+'/cancel?request_type='+request_type+'&lock_version='+lock_version"
                        :csrf_token="csrf_token"
                        css="btn red lighten-2"
                        label="Cancel Request"
                        message="Are you sure you want to cancel this request?">
                    </confirmable-action>
                </div>
            </div>
        </template>
        <template v-if="status === 'QUOTE_ACCEPTED'">
            <div class="row">
                <div class="col s12 m6 l3">
                    <div class="card-panel green lighten-4">Quote Accepted! Awaiting creating of a new File Issue.</div>
                </div>
            </div>
        </template>
        <template v-if="status === 'FILE_ISSUE_CREATED'">
            <div class="row">
                <div class="col s12 m6 l3">
                    <div class="card-panel green lighten-4">File issue created! FIXME add link here.</div>
                </div>
            </div>
        </template>
        <template v-if="status === 'CANCELLED_BY_AGENCY'">
            <div class="row">
                <div class="col s12 m6 l3">
                    <div class="card-panel red lighten-4">Request cancelled by Agency.</div>
                </div>
            </div>
        </template>
        <template v-if="status === 'CANCELLED_BY_QSA'">
            <div class="row">
                <div class="col s12 m6 l3">
                    <div class="card-panel red lighten-4">Request cancelled by QSA.</div>
                </div>
            </div>
        </template>
    </template>
</div>
`,
    data: function(): {items: RepresentationRequest[], quote: Quote|null} {
        let quote: Quote|null = null;

        if (this.quote_blob !== 'null') {
            const rawQuote = JSON.parse(this.quote_blob);
            quote = {
                id: rawQuote.id,
                issuedDate: rawQuote.issued_date,
                totalChargeCents: rawQuote.total_charge_cents,
                lineItems: [],
            };

            rawQuote.line_items.forEach((rawItem: any) => {
                if (quote) {
                    quote.lineItems.push({
                        description: rawItem.description,
                        quantity: rawItem.quantity,
                        chargePerUnitCents: rawItem.charge_per_unit_cents,
                        chargeQuantityUnit: rawItem.charge_quantity_unit,
                        chargeCents: rawItem.charge_cents,
                    });
                }
            });
        }

        return {
            items: [],
            quote: quote,
        };
    },
    props: ['status', 'request_type', 'request_id', 'lock_version', 'csrf_token', 'quote_blob'],
    methods: {
        syncItems: function(reps: RepresentationRequest[]) {
            this.items = reps;
        },
        formatCents: function(cents: number) {
            return (cents / 100).toLocaleString(undefined, {style: 'currency', currency: 'AUD'});
        },
        formatUnit: function(unit: string) {
            if (unit === 'qtr_hour') {
                return '15min';
            }
            return unit;
        },
    },
    updated: function() {
        this.$el.querySelectorAll('input,textarea,select').forEach(function(el) {
            if ((el as HTMLFormElement).value !== "") {
                if (el.nextElementSibling) {
                    el.nextElementSibling.classList.add('active');
                }
            }
        });
    },
});
