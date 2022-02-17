package internalstorage

import (
	"fmt"
	"strings"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type JSONQueryExpression struct {
	column string
	keys   []string

	not    bool
	values []string
}

func JSONQuery(column string, keys ...string) *JSONQueryExpression {
	return &JSONQueryExpression{column: column, keys: keys}
}

func (jsonQuery *JSONQueryExpression) Exist() *JSONQueryExpression {
	jsonQuery.not = false
	return jsonQuery
}

func (jsonQuery *JSONQueryExpression) NotExist() *JSONQueryExpression {
	jsonQuery.not = true
	return jsonQuery
}

func (jsonQuery *JSONQueryExpression) Equal(value string) *JSONQueryExpression {
	jsonQuery.not, jsonQuery.values = false, []string{value}
	return jsonQuery
}

func (jsonQuery *JSONQueryExpression) NotEqual(value string) *JSONQueryExpression {
	jsonQuery.not, jsonQuery.values = true, []string{value}
	return jsonQuery
}

func (jsonQuery *JSONQueryExpression) In(values ...string) *JSONQueryExpression {
	jsonQuery.not, jsonQuery.values = false, values
	return jsonQuery
}

func (jsonQuery *JSONQueryExpression) NotIn(values ...string) *JSONQueryExpression {
	jsonQuery.not, jsonQuery.values = true, values
	return jsonQuery
}

func (jsonQuery *JSONQueryExpression) Build(builder clause.Builder) {
	if stmt, ok := builder.(*gorm.Statement); ok {
		if len(jsonQuery.keys) == 0 {
			return
		}

		switch stmt.Dialector.Name() {
		case "mysql", "sqlite":
			_, _ = builder.WriteString("JSON_UNQUOTE(JSON_EXTRACT(" + stmt.Quote(jsonQuery.column) + ",")
			builder.AddVar(stmt, fmt.Sprintf(`$."%s"`, strings.Join(jsonQuery.keys, `"."`)))
			writeString(builder, "))")

			switch len(jsonQuery.values) {
			case 0:
				if jsonQuery.not {
					writeString(builder, " IS NULL")
				} else {
					writeString(builder, " IS NOT NULL")
				}
			case 1:
				if jsonQuery.not {
					writeString(builder, " != ")
				} else {
					writeString(builder, " = ")
				}
				builder.AddVar(builder, jsonQuery.values[0])
			default:
				if jsonQuery.not {
					writeString(builder, " NOT IN ")
				} else {
					writeString(builder, " IN ")
				}
				builder.AddVar(builder, jsonQuery.values)
			}
		case "postgres":
			stmt.WriteQuoted(jsonQuery.column)
			for _, key := range jsonQuery.keys[0 : len(jsonQuery.keys)-1] {
				writeString(stmt, " -> ")
				stmt.AddVar(builder, key)
			}
			writeString(stmt, " ->> ")
			stmt.AddVar(builder, jsonQuery.keys[len(jsonQuery.keys)-1])

			switch len(jsonQuery.values) {
			case 0:
				if jsonQuery.not {
					writeString(stmt, " IS NULL")
				} else {
					writeString(stmt, " IS NOT NULL")
				}
			case 1:
				if jsonQuery.not {
					writeString(stmt, " != ")
				} else {
					writeString(stmt, " = ")
				}
				builder.AddVar(builder, jsonQuery.values[0])
			default:
				if jsonQuery.not {
					writeString(builder, " NOT IN ")
				} else {
					writeString(builder, " IN ")
				}
				builder.AddVar(builder, jsonQuery.values)
			}
		}
	}
}

func buildParentOwner(db *gorm.DB, cluster, owner string, seniority int) interface{} {
	if seniority == 0 {
		return owner
	}

	parentOwner := buildParentOwner(db, cluster, owner, seniority-1)
	ownerQuery := db.Model(Resource{}).Select("uid").Where(map[string]interface{}{"cluster": cluster})
	if _, ok := parentOwner.(string); ok {
		return ownerQuery.Where("owner_uid = ?", parentOwner)
	}
	return ownerQuery.Where("owner_uid IN (?)", parentOwner)
}

func writeString(builder clause.Writer, str string) {
	_, _ = builder.WriteString(str)
}
