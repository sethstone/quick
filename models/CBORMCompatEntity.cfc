/**
 * A custom BaseEntity that proxies the cbORM methods to their Quick equivalent.
 */
component extends="quick.models.BaseEntity" accessors="true" {

	property
		name      ="CBORMCriteriaBuilderCompat"
		inject    ="provider:CBORMCriteriaBuilderCompat@quick"
		persistent="false";

	/**
	 * Creates an internal attribute struct for each persistent property
	 * on the entity.
	 *
	 * @properties  The array of properties on the entity.
	 *
	 * @return      A struct of attributes for the entity.
	 */
	private struct function generateAttributesFromProperties( required array properties ) {
		return arguments.properties.reduce( function( acc, prop ) {
			var newProp = paramAttribute( arguments.prop );
			if ( !newProp.persistent || newProp.keyExists( "fieldtype" ) ) {
				return arguments.acc;
			}
			arguments.acc[ newProp.name ] = newProp;
			return arguments.acc;
		}, {} );
	}

	function list(
		struct criteria = {},
		string sortOrder,
		numeric offset,
		numeric max,
		numeric timeout,
		boolean ignoreCase,
		boolean asQuery = true
	) {
		structEach( criteria, function( key, value ) {
			retrieveQuery().where( retrieveColumnForAlias( key ), value );
		} );
		if ( !isNull( sortOrder ) ) {
			retrieveQuery().orderBy( sortOrder );
		}
		if ( !isNull( offset ) && offset > 0 ) {
			retrieveQuery().offset( offset );
		}
		if ( !isNull( max ) && max > 0 ) {
			retrieveQuery().limit( max );
		}
		if ( asQuery ) {
			return retrieveQuery().setReturnFormat( "query" ).get();
		} else {
			return super.get();
		}
	}

	function countWhere() {
		for ( var key in arguments ) {
			retrieveQuery().where( retrieveColumnForAlias( key ), arguments[ key ] );
		}
		return retrieveQuery().count();
	}

	function deleteById( id ) {
		guardAgainstCompositePrimaryKeys();
		arguments.id = isArray( arguments.id ) ? arguments.id : [ arguments.id ];
		retrieveQuery().whereIn( keyNames()[ 1 ], arguments.id ).delete();
		return this;
	}

	function deleteWhere() {
		for ( var key in arguments ) {
			retrieveQuery().where( retrieveColumnForAlias( key ), arguments[ key ] );
		}
		return this.deleteAll();
	}

	function exists( id ) {
		if ( !isNull( id ) ) {
			guardAgainstCompositePrimaryKeys();
			retrieveQuery().where( keyNames()[ 1 ], arguments.id );
		}
		return retrieveQuery().exists();
	}

	function findAllWhere( criteria = {}, sortOrder ) {
		structEach( criteria, function( key, value ) {
			retrieveQuery().where( retrieveColumnForAlias( key ), value );
		} );
		if ( !isNull( sortOrder ) ) {
			var sorts = listToArray( sortOrder, "," ).map( function( sort ) {
				return replace( sort, " ", "|", "ALL" );
			} );
			retrieveQuery().orderBy( sorts );
		}
		return super.get();
	}

	function findWhere( criteria = {} ) {
		structEach( criteria, function( key, value ) {
			retrieveQuery().where( retrieveColumnForAlias( key ), value );
		} );
		return super.first();
	}

	function get( id, returnNew = false ) {
		if ( isNull( arguments.id ) && arguments.returnNew ) {
			return newEntity();
		} else if ( isNull( arguments.id ) ) {
			return super.get();
		}
		// This is written this way to avoid conflicts with the BIF `find`
		return invoke( this, "find", { id : arguments.id } );
	}

	function getAll( id, sortOrder ) {
		if ( isNull( id ) ) {
			if ( !isNull( sortOrder ) ) {
				var sorts = listToArray( sortOrder, "," ).map( function( sort ) {
					return replace( sort, " ", "|", "ALL" );
				} );
				retrieveQuery().orderBy( sorts );
			}
			return super.get();
		}
		guardAgainstCompositePrimaryKeys();
		var ids = isArray( id ) ? id : listToArray( id, "," );
		retrieveQuery().whereIn( keyNames()[ 1 ], ids );
		return super.get();
	}

	function new( properties = {} ) {
		return newEntity().fill( properties );
	}

	function populate( properties = {} ) {
		super.fill( properties );
		return this;
	}

	function save( entity ) {
		if ( isNull( entity ) ) {
			return super.save();
		}
		return entity.save();
	}

	function saveAll( entities = [] ) {
		entities.each( function( entity ) {
			entity.save();
		} );
		return this;
	}

	function newCriteria() {
		return CBORMCriteriaBuilderCompat.setEntity( this );
	}

	/**
	 * This method listens to non-existent method to create fluently:
	 *
	 * 1) FindByXXX operations
	 * 2) FindAllByXXX operations
	 * 3) countByXXX operations
	 *
	 */
	any function onMissingMethod( string missingMethodName, struct missingMethodArguments ) {
		var method = arguments.missingMethodName;
		var args   = arguments.missingMethodArguments;

		// Dynamic Find Unique Finders
		if ( left( method, 6 ) eq "findBy" and len( method ) GT 6 ) {
			listToArray(
				right( method, len( method ) - 6 ),
				"and",
				false,
				true
			).each( function( prop, index ) {
				this.resetQuery().where( prop, args[ index ] );
			} );

			return super.first();
		}
		// Dynamic find All Finders
		if ( left( method, 9 ) eq "findAllBy" and len( method ) GT 9 ) {
			listToArray(
				right( method, len( method ) - 9 ),
				"and",
				false,
				true
			).each( function( prop, index ) {
				this.resetQuery().where( prop, args[ index ] );
			} );

			return super.get();
		}
		// Dynamic countBy Finders
		if ( left( method, 7 ) eq "countBy" and len( method ) GT 7 ) {
			listToArray(
				right( method, len( method ) - 7 ),
				"and",
				false,
				true
			).each( function( prop, index ) {
				this.resetQuery().where( prop, args[ index ] );
			} );

			return super.count();
		}

		return super.onMissingMethod( argumentCollection = arguments );
	}


	private void function guardAgainstCompositePrimaryKeys() {
		if ( keyNames().len() > 1 ) {
			throw(
				type    = "InvalidKeyLength",
				message = "The CBORMCompatEntity cannot be used with composite primary keys."
			);
		}
	}

}
