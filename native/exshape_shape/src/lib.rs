use rustler::{self, Encoder, Env, Term};
use itertools::{Itertools, Either};

mod atoms {
    use ::rustler;
    pub use rustler::types::atom::*;
    rustler::atoms! { x, y }
}

rustler::init!("Elixir.Exshape.Shp", [native_nest_polygon_impl]);

mod point;
mod lineseg;
mod ring;
mod poly;

use ring::Ring;
use poly::Poly;
use point::Point;

struct Yes<T>(T);
impl <T: Encoder> Encoder for Yes<T> {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        (atoms::ok(), &self.0).encode(env)
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn native_nest_polygon_impl<'a>(rings: Vec<Ring<'a>>) -> Yes<Vec<Poly<'a>>> {
    let (mut polys, holes) = rings.into_iter().partition_map(|ring| {
        if ring.is_clockwise() {
            Either::Left(ring.into())
        } else {
            Either::Right(ring)
        }
    });
    nest_holes(&mut polys, holes);

    Yes(polys)
}

fn nest_holes<'a>(polys: &mut Vec<Poly<'a>>, holes: Vec<Ring<'a>>) {
    if holes.len() == 1 {
        // if there's only a single hole, we won't bother slicing the
        // polygons, since we'd just throw away all that work anyway.
        let hole = holes.into_iter().next().unwrap();
        process(polys, hole, Ring::contains_unsliced)
    } else {
        for hole in holes {
            process(polys, hole, Ring::contains);
        }
    }
}

fn process<'a>(polys: &mut Vec<Poly<'a>>, hole: Ring<'a>, contain: fn(&Ring<'a>, &Point) -> bool) {
    match polys.len() {
        0 => {
            polys.push(hole.into());
        }
        1 => {
            polys[0].push(hole);
        }
        _ => {
            // in the original, this is recursive, but we'll do it
            // iteratively.  What we want to do is find the first poly
            // which contains the first point of the ring and push the
            // hole onto it.  If it doesn't fit in any poly, just smash
            // it onlo the last.
            let pt = hole.first_point();
            match polys.iter_mut().find(|poly| contain(poly.first_ring(), pt)) {
                Some(poly) => {
                    poly.push(hole);
                }
                None => {
                    polys.last_mut().unwrap().push(hole);
                }
            }
        }
    }
}
