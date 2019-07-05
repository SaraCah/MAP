/// <amd-module name='service-quote'/>

import Vue from "vue";
import VueResource from "vue-resource";
Vue.use(VueResource);


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


Vue.component('service-quote', {
    template: `
<div>
    <template v-if="quote != null">
        <div class="card">
            <div class="card-content">
                <span class="card-title">{{title || "Quote"}}</span>

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

                <div class="row">
                    <div class="col s12">
                        <p>Issued: {{quote.issuedDate}}</p>
                    </div>
                </div>

                <slot></slot>
            </div>
        </div>
    </template>
</div>
`,
    data: function(): {quote: Quote|null} {
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
            quote: quote,
        };
    },
    props: ['quote_blob', 'title'],
    methods: {
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
});
