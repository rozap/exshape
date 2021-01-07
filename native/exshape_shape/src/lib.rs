use rustler::{Encoder, Env, NifResult, SchedulerFlags, Term, rustler_export_nifs};
use itertools::{Itertools, Either};

mod atoms {
    pub use rustler::types::atom::*;
    rustler::rustler_atoms! {
        atom x;
        atom y;
    }
}

rustler_export_nifs! {
    "Elixir.Exshape.Shp",
    [
        ("native_nest_polygon_impl", 1, nest_polygon, SchedulerFlags::DirtyCpu)
    ],
    None
}

mod point;
mod lineseg;
mod ring;
mod poly;

use ring::Ring;
use poly::Poly;
use point::Point;

fn nest_polygon<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let rings = args[0].decode::<Vec<Ring<'a>>>()?;

    let (mut polys, holes) = rings.into_iter().partition_map(|ring| {
        if ring.is_clockwise() {
            Either::Left(ring.into())
        } else {
            Either::Right(ring)
        }
    });
    nest_holes(&mut polys, holes);

    Ok((atoms::ok(), polys).encode(env))
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
