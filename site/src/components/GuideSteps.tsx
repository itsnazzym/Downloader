import {
  Accordion, AccordionContent, AccordionItem, AccordionTrigger,
} from './ui/accordion';

type Step = { number: string; title: string; body: string };

export default function GuideSteps({ steps, label }: { steps: Step[]; label: string }) {
  return (
    <section className="guide-steps" aria-label={label} data-reveal>
      <Accordion type="multiple" defaultValue={steps.map((step) => step.number)} className="guide-accordion">
        {steps.map((step) => (
          <AccordionItem value={step.number} key={step.number} className="guide-accordion-item">
            <AccordionTrigger className="guide-accordion-trigger">
              <span className="guide-accordion-number">{step.number}</span>
              <span className="guide-accordion-title">{step.title}</span>
            </AccordionTrigger>
            <AccordionContent className="guide-accordion-content"><p>{step.body}</p></AccordionContent>
          </AccordionItem>
        ))}
      </Accordion>
    </section>
  );
}
