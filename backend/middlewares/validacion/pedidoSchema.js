const { checkSchema } = require("express-validator");

module.exports = checkSchema({
  total: {
    in: ["body"],
    isFloat: {
      options: { min: 0 },
      errorMessage: "El total debe ser un número positivo."
    },
    toFloat: true
  },
  metodo_pago: {
    in: ["body"],
    isString: {
      errorMessage: "El método de pago es obligatorio."
    },
    isLength: {
      options: { min: 2, max: 50 },
      errorMessage: "El método de pago debe tener entre 2 y 50 caracteres."
    },
    trim: true
  },
direccion_entrega: {
  in: ["body"],
  isString: {
    errorMessage: "La dirección de entrega es obligatoria."
  },
  isLength: {
    options: { min: 5, max: 255 },
    errorMessage: "La dirección debe tener entre 5 y 255 caracteres."
  },
  trim: true
},
  cupon: {
    in: ["body"],
    optional: true,
    isString: {
      errorMessage: "El cupón debe ser un texto válido."
    },
    trim: true
  },
  notas: {
    in: ["body"],
    optional: true,
    isString: {
      errorMessage: "Las notas deben ser texto."
    },
    trim: true
  }
});
