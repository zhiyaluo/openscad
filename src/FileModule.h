#pragma once

#include <string>
#include <unordered_map>
#include <unordered_set>
#include <time.h>

#include "module.h"
#include "value.h"
#include "localscope.h"

class FileModule : public AbstractModule, public ASTNode
{
public:
	FileModule(const std::string &path, const std::string &filename);
	~FileModule();

	AbstractNode *instantiate(const Context *ctx, const ModuleInstantiation *inst, EvalContext *evalctx = nullptr) const override;
	void print(std::ostream &stream, const std::string &indent) const override;
	AbstractNode *instantiateWithFileContext(class FileContext *ctx, const ModuleInstantiation *inst, EvalContext *evalctx) const;

	void setModulePath(const std::string &path) { this->path = path; }
	const std::string &modulePath() const { return this->path; }
	void addUseNode(const UseNode &usenode);
	void resolveUseNodes();
	void addIncludeNode(const IncludeNode &includenode);
	void resolveIncludeNodes();
	time_t includesChanged() const;
	time_t handleDependencies();
	bool hasExternals() const { return !this->externalDict.empty(); }
	bool isHandlingDependencies() const { return this->is_handling_dependencies; }
	void resolveExternals();

	std::vector<shared_ptr<UseNode>> getUseNodes() const;
	
	LocalScope scope;
	std::unordered_map<std::string, shared_ptr<ExternalNode>> externalDict;
	std::vector<shared_ptr<ExternalNode>> externalList;
private:
	struct IncludeFile {
		std::string filename;
	};

	time_t includeModified(const IncludeNode &node) const;

	bool is_handling_dependencies;

	std::string path;
	std::string filename;
};
