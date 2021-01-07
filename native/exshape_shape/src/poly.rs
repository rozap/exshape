use rustler::{Decoder, Encoder, Error, NifResult, Term};

use crate::ring::Ring;

pub struct Poly<'a> {
    rings: Vec<Ring<'a>>
}

impl <'a> Poly<'a> {
    pub fn first_ring(&self) -> &Ring<'a> {
        &self.rings[0]
    }

    pub fn push(&mut self, ring: Ring<'a>) {
        self.rings.push(ring)
    }
}

impl <'a> From<Ring<'a>> for Poly<'a> {
    fn from(ring: Ring<'a>) -> Self {
        Self { rings: vec![ring] }
    }
}

impl <'a> Decoder<'a> for Poly<'a> {
    fn decode(term: Term<'a>) -> NifResult<Self> {
        let rings = term.decode::<Vec<_>>()?;
        if rings.is_empty() {
            return Err(Error::BadArg);
        }
        Ok(Poly { rings })
    }
}

impl <'a> Encoder for Poly<'a> {
    fn encode<'b>(&self, env: rustler::Env<'b>) -> Term<'b> {
        self.rings.encode(env)
    }
}
