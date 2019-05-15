/// <amd-module name='conversation'/>


import Vue from "vue";
import VueResource from "vue-resource";
import Utils from "./utils";

Vue.use(VueResource);

interface Message {
    message: string;
    author: string;
    timestamp: number;
}

Vue.component('conversation', {
    template: `
<div class="card grey lighten-5">
    <div class="card-content">
        <h4>{{title}}</h4>
        <div v-for="message in messages" class="card">
            <div class="card-content">
                <div style="white-space: pre">{{message.message}}</div>
                <br>
                <div>
                    <span class="grey-text">{{message.author}} - {{formatTimestamp(message.timestamp)}}</span>
                </div>
            </div>
        </div>
        <div>
            <textarea ref="message" class="materialize-textarea" placeholder="Type your message!" v-model="message"></textarea>
            <a class="btn" ref="postButton" v-on:click="post()">Post Message</a>
        </div>
    </div>
</div>
`,
    data: function():
        {
            messages: Message[],
            busy: boolean,
            message: string,
        } {
            return {
                messages: [],
                busy: false,
                message: '',
            };
    },
    props: {
        handle_id: String,
        csrf_token: String,
        title: {
            type: String,
            default: "Conversation",
        },
    },
    methods: {
        loadMessages: function() {
            this.$http.get('/get-messages?handle_id=' + this.handle_id)
                .then((response: any) => response.json())
                .then((json: any) => {
                    this.messages = json.messages;
                });
        },
        post: function() {
            if (this.busy) {
                return;
            }

            if (this.message === '') {
                return;
            }

            this.busy = true;

            this.$http.post(
                '/post-message',
                {
                    handle_id: this.handle_id,
                    message: this.message,
                    authenticity_token: this.csrf_token,
                },
                {
                    emulateJSON: true,
                })
                .then(() => {
                    this.busy = false;
                    this.message = '';
                    this.loadMessages();
                    (this.$refs.message as HTMLFormElement).focus();
                });
        },
        formatTimestamp: function(epochTime: number) {
            return Utils.localDateForEpoch(epochTime);
        },
    },
    mounted: function() {
        this.loadMessages();
        setInterval(() => {
            this.loadMessages();
        }, 5 * 1000);
    },
});
