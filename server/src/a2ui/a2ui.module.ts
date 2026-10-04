import { Module } from '@nestjs/common';
import { A2uiParserService } from './a2ui-parser.service';
import { A2uiPromptService } from './a2ui-prompt.service';
import { A2uiValidationService } from './a2ui-validation.service';

/**
 * Everything that knows what A2UI is.
 *
 * Kept as its own module because the agent used to own half of it. One module,
 * one catalog, one validator: the prompt that asks for a tree and the code that
 * judges it are now written against the same source.
 */
@Module({
  providers: [A2uiPromptService, A2uiParserService, A2uiValidationService],
  exports: [A2uiPromptService, A2uiParserService, A2uiValidationService],
})
export class A2uiModule {}
