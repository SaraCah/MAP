/// <amd-module name='conversation'/>


import Vue from "vue";
import VueResource from "vue-resource";
// import Utils from "./utils";
// import UI from "./ui";
Vue.use(VueResource);
// import Utils from "./utils";
// import UI from "./ui";

interface Message {
    message: String;
    author: String;
    timestamp: Number;
}

Vue.component('conversation', {
    template: `
<div class="card grey lighten-5">
    <div class="card-content">
        <h4>Conversation</h4>
        <div v-for="message in messages" class="card">
            <div class="card-content">
                <div v-html="escapeMessage(message.message)"></div>
                <br>
                <div>
                    <span class="grey-text">{{message.author}}</span> - 
                    <span class="grey-text">{{localDate(message.timestamp)}}</span>
                </div>
            </div>
        </div>
        <div>
            <textarea class="materialize-textarea" placeholder="Type your message!" v-model="message"></textarea>
            <a class="btn" ref="postButton" v-on:click="post()">Post Message</a>
        </div>
    </div>
</div>
`,
    data: function():
        {
            messages: Message[],
            busy: Boolean,
            message: String,
        }
    {
            return {
                messages: [],
                busy: false,
                message: '',
            };
    },
    props: ['record_type', 'id', 'csrf_token'],
    methods: {
        loadMessages: function() {
            this.$http.get('/get_messages?record_type='+this.record_type+'&id='+this.id)
                .then((response: any) => response.json())
                .then((json: any) => {
                    this.messages = json.messages;
                });
        },
        post: function() {
            if (this.busy) {
                return;
            }

            if (this.message == '') {
                return;
            }

            this.busy = true;

            this.$http.post(
                '/post_message',
                {
                    record_type: this.record_type,
                    id: this.id,
                    message: this.message,
                    authenticity_token: this.csrf_token,
                },
                {
                    emulateJSON: true
                })
                .then(() => {
                    this.busy = false;
                    this.message = '';
                    this.loadMessages();
                });
        },
        localDate: function(epoch:number) {
            return new Date(epoch).toLocaleString();
        },
        escapeMessage: function(message:string) {
            return message.replace(/[&<>"\n]/g, function (tag) {
                var chars_to_replace:any = {
                    '&': '&amp;',
                    '<': '&lt;',
                    '>': '&gt;',
                    '"': '&quot;',
                    '\n': '<br>',
                };

                return chars_to_replace[tag] || tag;
            });
        },
    },
    mounted: function() {
        this.loadMessages()
    }
});