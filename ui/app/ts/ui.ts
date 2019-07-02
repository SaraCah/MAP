/// <amd-module name='ui'/>

declare var M: any;

export default class UI {
    public static genericModal(message: string) {
        const modal = document.createElement('div');
        const content = document.createElement('div');
        modal.appendChild(content);

        modal.className = 'modal';
        content.className = 'modal-content';

        content.innerText = message;

        document.body.appendChild(modal);

        M.Modal.init(modal).open();
    }

    public static genericHTMLModal(content: HTMLElement | string, modalClasses?: string[]): [any, HTMLElement] {
        let node: HTMLElement | null = null;

        if (typeof(content) == 'string') {
            node = document.createElement('div');
            node.innerHTML = content;
        } else {
            node = content;
        }

        // Clear any previous modals
        document.querySelectorAll('.modal-generated-elt').forEach(function (elt) {
            if (elt.parentNode) {
                elt.parentNode.removeChild(elt);
            }
        });

        const modal = document.createElement('div');
        const contentContainer = document.createElement('div');

        modal.appendChild(contentContainer);

        modal.className = 'modal';
        modal.classList.add('modal-generated-elt')

        if (modalClasses) {
            for (const className of modalClasses) {
                modal.classList.add(className);
            }
        }


        contentContainer.className = 'modal-content';

        contentContainer.appendChild(node);

        document.body.appendChild(modal);

        const modalObj = M.Modal.init(modal);
        modalObj.open();

        return [modalObj, contentContainer];
    }
}
